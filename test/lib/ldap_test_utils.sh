#!/usr/bin/env bash
# vim: ts=4

# Overridable defaults
[ -z "$PASSWORD_DIR" ] && PASSWORD_DIR="passwords"

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
		echo "!!! ERROR: Can't read attribute '$attr' of '$to'. !!!"
		return 1
	fi

	# Test write: the new value is the same, but permission is required
	ldapmodify -xD "$as" -y "$passwdfile" "$@" >/dev/null <<-EOF
		dn: $to
		changetype: modify
		replace: $attr
		$attr_reset
	EOF

	# If write fail
	if [ $? -ne 0 -a "$neg" != 1 ]; then
		echo "!!! FAIL: '$as' failed to write attribute '$attr' of '$to' !!!"
		return 1
	elif [ $? -eq 0 -a "$neg" == 1 ]; then
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
	if [ -n "$attr" ]; then
		ldapsearch -xD "$as" -y "$passwdfile" -b "$to" $attr >/dev/null
	else
		ldapsearch -xD "$as" -y "$passwdfile" -b "$to" >/dev/null
	fi

	return $?
}


function __test_ldap_parse_args() {
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
