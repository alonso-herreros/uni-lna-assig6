#!/usr/bin/env bash

# Constant defaults
[ -z "$PASSWORD_DIR" ] && PASSWORD_DIR="passwords"

# Test modifying an LDAP entry
function _test_ldap_modify() {
	# Args
	while [ -n "$1" ]; do
		case "$1" in
			--as )
				as="$2"
				shift 2;;
			--to | --target )
				to="$2"
				shift 2;;
			--attr | --attribute )
				attr="$2"
				shift 2;;
			-- )
				shift
				break;;
			* )
				echo "Error parsing argument '$1'."
				echo "Only arguments after `--` are passed to ldapmodify."
				return 3;
		esac
	done

	passwdfile="$PASSWORD_DIR/$as"

	# Save attribute
	attr_reset=$(ldapsearch -xWD "$as" -y "$passwdfile" -b "$to" $attr -LLL \
		| grep "$attr")
	# If save failed
	if [ $? -ne 0 -o -z "$attr_reset" ]; then
		echo "Can't read attribute '$attr' of '$to'."
		return $?
	fi

	# Test write
	ldapmodify -xD "$as" -y "$passwdfile" "$@" <<-EOF
		dn: $to
		changetype: modify
		replace: $attr
		$attr: testval
	EOF

	# If write fail
	if [ $? -ne 0 ]; then
		echo "Failed to write attribute '$attr' of '$to'."
		return $?
	fi

	# If write succeed, reset
	ldapmodify -xD "$as" -y "$passwdfile" "$@" <<-EOF
		dn: $to
		changetype: modify
		replace: $attr
		$attr_reset
	EOF

	return 0
}
