#!/usr/bin/env bash
# vim: ts=4

# ---- Overridable defaults ----
[ -z "$PASSWORD_DIR" ] && PASSWORD_DIR="passwords"

# Abstraction to test an arbitrary access level
function _test_ldap_access() {
	# First arg should be access level
	level="$1"
	shift

	echo "Test '$level' access to '$to': '$attr' by '$as'"

	case "$level" in
		W )
			_test_ldap_write "$@";;
		R )
			_test_ldap_read "$@" \
			&& _test_ldap_write -n "$@";;
		* )
			_test_ldap_read -n "$@";;
	esac
	return $?
}

# Test modifying an LDAP entry
function _test_ldap_write() {
	# Args
	__test_ldap_parse_args "$@"
	# Discard args up to and including '--'
	while [ -n "$1" -a "$1" != "--" ]; do shift; done

	# Save attribute
	attr_reset=$(ldapsearch -xD "$as" -y "$passwdfile" -b "$to" $attr -LLL \
		| grep "^$attr")
	# If save failed
	if [ $? -ne 0 -o -z "$attr_reset" ]; then
		echo "!!! ERROR: Can't read attribute '$attr' of '$to' !!!"
		return 1
	fi

	# Test write: the new value is the same, but permission is required
	ldapmodify -xD "$as" -y "$passwdfile" "$@" >/dev/null 2>&1 <<-EOF
		dn: $to
		changetype: modify
		replace: $attr
		$attr_reset
	EOF
	fail=$?

	if [ $fail -ne 0 -a $neg -ne 1 ]; then
		echo "!!! FAIL: '$as' failed to write attribute '$attr' of '$to' !!!"
		return 1
	elif [ $fail -eq 0 -a "$neg" -eq 1 ]; then
		echo "!!! FAIL: '$as' managed to write attribute '$attr' of '$to' !!!"
		return 1
	fi
}

function _test_ldap_read() {
	# Args
	__test_ldap_parse_args "$@"
	# Discard args up to and including '--'
	while [ -n "$1" -a "$1" != "--" ]; do shift; done

	# Search for attribute
	ldapsearch -xD "$as" -y "$passwdfile" -b "$to" $attr "$@" -LLL 2>/dev/null \
		| grep "^$attr" >/dev/null
	fail=$?

	if [ $fail -ne 0 -a $neg -ne 1 ]; then
		echo "!!! FAIL: '$as' failed to read attribute '$attr' of '$to' !!!"
		return 1
	elif [ $fail -eq 0 -a $neg -eq 1 ]; then
		echo "!!! FAIL: '$as' managed to read attribute '$attr' of '$to' !!!"
		return 1
	fi
}


function __test_ldap_parse_args() {
	neg=0
	as=
	to=
	attr=

	while [ -n "$1" ]; do
		case "$1" in
			-n | --neg )
				neg=1
				shift;;
			-D | --as )
				as="$2"
				shift 2;;
			-b | --to | --target )
				to="$2"
				shift 2;;
			-a | --attr | --attribute )
				attr="$2"
				shift 2;;
			-- )
				shift
				break;;
			* )
				echo "Error parsing argument '$1'."
				echo "Only arguments after '--' are passed down."
				return 3;
		esac
	done

	passwdfile="$PASSWORD_DIR/$as"
}
