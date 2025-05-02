TEST_DIR = test

BUILD_DIR = build
MARKER_DIR = ${BUILD_DIR}/markers

HOST = ldapi:///
ADMIN = cn=admin,dc=marvel,dc=com


all: base permissions
test: test-permissions

.PHONY: all test \
	base permissions passwords \
	test-permissions \
	clean

BASE_MARKER = ${MARKER_DIR}/base.marker
base: ${BASE_MARKER}
${BASE_MARKER}: entries/base.ldif | ${MARKER_DIR}
	sudo ldapadd -xWD ${ADMIN} -f $<
	@touch $@

PERMISSIONS_MARKER = ${MARKER_DIR}/permissions.marker
permissions: ${PERMISSIONS_MARKER}
${PERMISSIONS_MARKER}: updates/permissions.ldif | ${MARKER_DIR}
	sudo ldapmodify -WY EXTERNAL -f $?
	@touch $@

# TODO: make this depend on an actual passwords LDIF
PASSWORDS_MARKER = ${MARKER_DIR}/passwords.marker
passwords: ${PASSWORDS_MARKER}
${PASSWORDS_MARKER}: ${TEST_DIR}/passwords/* | ${MARKER_DIR}
	test/set-passwords.sh -p "${TEST_DIR}/passwords"
	@touch $@


test-permissions: base permissions passwords
	test/test-permissions.sh -p "${TEST_DIR}/passwords"

${MARKER_DIR}:
	mkdir -p $@

# Clean
clean:
	-ldapmodify -xWD "${ADMIN}" -f updates/icoe-nuke.ldif
	rm -rf ${BUILD_DIR}
