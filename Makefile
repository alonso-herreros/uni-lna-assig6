TEST_DIR = test

BUILD_DIR = build
MARKER_DIR = ${BUILD_DIR}/markers

HOST = ldapi:///
ADMIN = cn=admin,dc=marvel,dc=com
PASSWDFILE := $(shell mktemp -u --tmpdir ldap_secret.XXXX)

LDAP_OPTS       = -xD "${ADMIN}" -y "${PASSWDFILE}"
ROOT_LDAP_OPTS  = -Y EXTERNAL -y "${PASSWDFILE}"

LDAPADD_         = ldapadd ${LDAP_OPTS}
LDAPMODIFY_      = ldapmodify ${LDAP_OPTS}
SUDO_LDAPADD_    = sudo ldapadd ${ROOT_LDAP_OPTS}
SUDO_LDAPMODIFY_ = sudo ldapmodify ${ROOT_LDAP_OPTS}

SCHEMAS = marvel

APPEARANCES_DIRS    = $(wildcard updates/appearances/*/)
APPEARANCES_RELDIRS = $(patsubst updates/%/,%,${APPEARANCES_DIRS})
APPEARANCES_CHARS   = $(patsubst updates/appearances/%/,%,${APPEARANCES_DIRS})

all: base appearances permissions
test: test-permissions

.PHONY: all test \
	base permissions passwords \
	test-permissions \
	clean

# Ensures deletion
.INTERMEDIATE: ${PASSWDFILE}

# ---- Aliases ----
# Make these targets be aliases for their markers
MARKER_ALIASES = schema base appearances permissions passwords
${MARKER_ALIASES}: %: ${MARKER_DIR}/%

SCHEMA_MARKER      = ${MARKER_DIR}/schema
BASE_MARKER        = ${MARKER_DIR}/base
APPEARANCES_MARKER = ${MARKER_DIR}/appearances
PERMISSIONS_MARKER = ${MARKER_DIR}/permissions
PASSWORDS_MARKER   = ${MARKER_DIR}/passwords

SCHEMAS_MARKERS    = $(addprefix ${MARKER_DIR}/schema/, ${SCHEMAS})
APPEARANCES_CHARS_MARKERS = $(addprefix ${MARKER_DIR}/, ${APPEARANCES_RELDIRS})

# Prevents deletion
SECONDARY += $(addsuffix /base,${SCHEMAS_MARKERS})
SECONDARY += $(addsuffix /classes,${SCHEMAS_MARKERS})
SECONDARY += $(addsuffix /attrs,${SCHEMAS_MARKERS})
SECONDARY += $(addsuffix /firstAppearance,${APPEARANCES_CHARS_MARKERS})
SECONDARY += $(addsuffix /comics,${APPEARANCES_CHARS_MARKERS})
SECONDARY += $(addsuffix /movies,${APPEARANCES_CHARS_MARKERS})
.SECONDARY: ${SECONDARY}


# ---- Actual recipes (for markers) ----

# Schema
${SCHEMA_MARKER}: ${SCHEMAS_MARKERS} | ${MARKER_DIR}
	@touch $@

${SCHEMAS_MARKERS}: %: %/classes %/attrs | ${MARKER_DIR}
	@touch $@

${MARKER_DIR}/schema/%/classes: schema/%/classes.ldif \
		${MARKER_DIR}/schema/%/attrs ${MARKER_DIR}/schema/%/base \
		| ${PASSWDFILE} ${MARKER_DIR}
	${SUDO_LDAPMODIFY_} -f $<
	@touch $@

${MARKER_DIR}/schema/%/attrs: schema/%/attrs.ldif \
		${MARKER_DIR}/schema/%/base \
		| ${PASSWDFILE} ${MARKER_DIR}
	${SUDO_LDAPMODIFY_} -f $<
	@touch $@

${MARKER_DIR}/schema/%/base: schema/%.ldif \
		| ${PASSWDFILE} ${MARKER_DIR}
	-${SUDO_LDAPADD_} -f $<
	@# This is very important. It makes the dirs. Without it, many things \
	 # will fail.
	@mkdir -p $(@D) && touch $@


# Tree base
${BASE_MARKER}: entries/base.ldif ${SCHEMA_MARKER} \
		| ${PASSWDFILE} ${MARKER_DIR}
	${LDAPADD_} -f $<
	@touch $@

# Appearances
${APPEARANCES_MARKER}: ${APPEARANCES_CHARS_MARKERS} \
		| ${MARKER_DIR}
	@touch $@

${MARKER_DIR}/appearances/%: ${MARKER_DIR}/appearances/%/firstAppearance \
		${MARKER_DIR}/appearances/%/comics ${MARKER_DIR}/appearances/%/movies \
		| ${MARKER_DIR}
	@touch $@

${MARKER_DIR}/%/comics: updates/%/comics.ldif \
		${MARKER_DIR}/%/firstAppearance ${SCHEMA_MARKER} ${BASE_MARKER} \
		| ${PASSWDFILE}
	@# Error 20 is existing entry, e.g. trying to add a class twice
	${LDAPMODIFY_} -cf "$<" || [ $$? -eq 20 ]
	@mkdir -p $(@D) && touch $@

${MARKER_DIR}/%/movies: updates/%/movies.ldif \
		${MARKER_DIR}/%/firstAppearance ${SCHEMA_MARKER} ${BASE_MARKER} \
		| ${PASSWDFILE}
	${LDAPMODIFY_} -cf "$<" || [ $$? -eq 20 ]
	@mkdir -p $(@D) && touch $@

${MARKER_DIR}/%/firstAppearance: updates/%/firstAppearance.ldif \
		${SCHEMA_MARKER} ${BASE_MARKER} \
		| ${PASSWDFILE}
	${LDAPMODIFY_} -cf "$<" || [ $$? -eq 20 ]
	@mkdir -p $(@D) && touch $@

#Permissions
${PERMISSIONS_MARKER}: updates/permissions.ldif \
		| ${PASSWDFILE} ${MARKER_DIR}
	${SUDO_LDAPMODIFY_} -f $<
	@touch $@

# Passwords
# TODO: make this depend on an actual passwords LDIF
${PASSWORDS_MARKER}: ${TEST_DIR}/passwords/* ${BASE_MARKER} \
		| ${MARKER_DIR}
	test/set-passwords.sh -p "${TEST_DIR}/passwords"
	@touch $@


# ---- Test recipe ----
test-permissions: base appearances permissions passwords
	test/test-permissions.sh -p "${TEST_DIR}/passwords"


# Using `stty -echo` because POSIX read doesn't support silent mode
${PASSWDFILE}:
	@printf "Enter LDAP Admin Password: " >&2 && \
		stty -echo && read ldap_passwd; stty echo; \
		printf "\n" >&2; \
		echo "$$ldap_passwd" | tr -d "\n" > "${PASSWDFILE}"
	@chmod 400 "${PASSWDFILE}"


${MARKER_DIR}:
	mkdir -p $@

# Clean
clean: | ${PASSWDFILE}
	-${LDAPMODIFY_} -cf updates/icoe-nuke.ldif
	-${SUDO_LDAPMODIFY_} -cf schema/clean.ldif
	rm -rf ${BUILD_DIR}
