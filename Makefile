TEST_DIR = test

BUILD_DIR = build
MARKER_DIR = ${BUILD_DIR}/markers

HOST = ldapi:///
ADMIN = cn=admin,dc=marvel,dc=com
PASSWDFILE := $(shell mktemp -u --tmpdir ldap_secret.XXXX)
SCHEMAS = marvel


all: base permissions
test: test-permissions

.PHONY: all test \
	base permissions passwords \
	test-permissions \
	clean

.INTERMEDIATE: ${PASSWDFILE}

# ---- Aliases ----
# Make these targets be aliases for their markers
MARKER_ALIASES = schema base permissions passwords
${MARKER_ALIASES}: %: ${MARKER_DIR}/%

SCHEMA_MARKER      = ${MARKER_DIR}/schema
BASE_MARKER        = ${MARKER_DIR}/base
PERMISSIONS_MARKER = ${MARKER_DIR}/permissions
PASSWORDS_MARKER   = ${MARKER_DIR}/passwords

SCHEMAS_MARKERS    = $(addprefix ${MARKER_DIR}/schema/, ${SCHEMAS})

.SECONDARY: $(join ${SCHEMAS_MARKERS}, /base /classes /attrs)


# ---- Actual recipes (for markers) ----

# Schema
${SCHEMA_MARKER}: ${SCHEMAS_MARKERS} | ${MARKER_DIR}
	@touch $@

${SCHEMAS_MARKERS}: %: %/classes %/attrs | ${MARKER_DIR}
	@touch $@

${MARKER_DIR}/schema/%/classes: schema/%/classes.ldif \
		${MARKER_DIR}/schema/%/attrs ${MARKER_DIR}/schema/%/base \
		| ${PASSWDFILE} ${MARKER_DIR}
	sudo ldapmodify -WY EXTERNAL -y ${PASSWDFILE} -f $<
	@touch $@

${MARKER_DIR}/schema/%/attrs: schema/%/attrs.ldif \
		${MARKER_DIR}/schema/%/base \
		| ${PASSWDFILE} ${MARKER_DIR}
	[ -f $< ] && sudo ldapmodify -WY EXTERNAL -y ${PASSWDFILE} -f $<
	@touch $@

${MARKER_DIR}/schema/%/base: schema/%.ldif \
		| ${PASSWDFILE} ${MARKER_DIR}
	-sudo ldapadd -WY EXTERNAL -y ${PASSWDFILE} -f $<
	@# This is very important. It makes the dirs. Without it, many things \
	 # will fail.
	@mkdir -p $(@D) && touch $@


# Tree base
${BASE_MARKER}: entries/base.ldif ${SCHEMA_MARKER} \
		| ${PASSWDFILE} ${MARKER_DIR}
	ldapadd -xWD ${ADMIN} -y ${PASSWDFILE} -f $<
	@touch $@

#Permissions
${PERMISSIONS_MARKER}: updates/permissions.ldif ${BASE_MARKER} \
		| ${PASSWDFILE} ${MARKER_DIR}
	sudo ldapmodify -WY EXTERNAL -y ${PASSWDFILE} -f $<
	@touch $@

# Passwords
# TODO: make this depend on an actual passwords LDIF
${PASSWORDS_MARKER}: ${TEST_DIR}/passwords/* ${BASE_MARKER} \
		| ${MARKER_DIR}
	test/set-passwords.sh -p "${TEST_DIR}/passwords"
	@touch $@


# ---- Test recipe ----
test-permissions: base permissions passwords
	test/test-permissions.sh -p "${TEST_DIR}/passwords"


# Using `stty -echo` because POSIX read doesn't support silent mode
${PASSWDFILE}:
	@printf "Enter LDAP Admin Password: " >&2 && \
		stty -echo && read ldap_passwd; stty echo; \
		printf "\n" >&2; \
		echo "$$ldap_passwd" | tr -d "\n" > ${PASSWDFILE}
	@chmod 400 "${PASSWDFILE}"


${MARKER_DIR}:
	mkdir -p $@

# Clean
clean: | ${PASSWDFILE}
	-ldapmodify -xWD "${ADMIN}" -y ${PASSWDFILE} -f updates/icoe-nuke.ldif
	-sudo ldapmodify -WY EXTERNAL -y ${PASSWDFILE} -f schema/clean.ldif
	rm -rf ${BUILD_DIR}
