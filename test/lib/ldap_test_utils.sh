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
	attr_reset=$(ldapsearch -xWD "$as" -y "$passwdfile" -b "$to" $attr -LLL \
		| grep "$attr")
	# If save failed
	if [ $? -ne 0 -o -z "$attr_reset" ]; then
		echo "Can't read attribute '$attr' of '$to'."
		return 1
	fi

	# Test write - the value is the same but permission is required
	ldapmodify -xD "$as" -y "$passwdfile" "$@" <<-EOF
		dn: $to
		changetype: modify
		replace: $attr
		$attr_reset
	EOF

	return $?
	# If write fail
	# if [ $? -ne 0 ]; then
	# 	echo "Failed to write attribute '$attr' of '$to'."
	# 	return $?
	# fi
}


function __test_ldap_parse_args() {
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
				echo "Only arguments after '--' are passed down."
				return 3;
		esac
	done

	passwdfile="$PASSWORD_DIR/$as"
}
