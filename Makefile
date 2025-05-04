TEST_DIR = test

BUILD_DIR = build
MARKER_DIR = ${BUILD_DIR}/markers

HOST = ldapi:///
ADMIN = cn=admin,dc=marvel,dc=com
PASSWDFILE := $(shell mktemp -u --tmpdir ldap_secret.XXXX)


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
${MARKER_ALIASES}: %: ${MARKER_DIR}/%.marker

SCHEMA_MARKER      = ${MARKER_DIR}/schema.marker
BASE_MARKER        = ${MARKER_DIR}/base.marker
PERMISSIONS_MARKER = ${MARKER_DIR}/permissions.marker
PASSWORDS_MARKER   = ${MARKER_DIR}/passwords.marker


# ---- Actual recipes for markers ----

${BASE_MARKER}: entries/base.ldif \
		| ${PASSWDFILE} ${MARKER_DIR}
	sudo ldapadd -xWD ${ADMIN} -y ${PASSWDFILE} -f $<
	@touch $@

${PERMISSIONS_MARKER}: updates/permissions.ldif ${BASE_MARKER} \
		| ${PASSWDFILE} ${MARKER_DIR}
	sudo ldapmodify -WY EXTERNAL -y ${PASSWDFILE} -f $<
	@touch $@

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
	rm -rf ${BUILD_DIR}
