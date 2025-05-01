#!/usr/bin/env bash

PASSWORD_DIR="passwords"

ADMIN="cn=admin,dc=marvel,dc=com"

while [ -n "$1" ]; do case "$1" in
    -p | --passwords )
        PASSWORD_DIR="$2"
        shift 2;;
    * )
        break;;
esac; done

PASSWDFILE="$PASSWORD_DIR/$ADMIN"

for newpasswdfile in $PASSWORD_DIR/*,dc=com; do
    who="$(basename $newpasswdfile)"

    # Skip if this is admin
    case "$who" in "cn=admin"* ) continue;; esac

    echo "Setting password for '$who'"
    ldappasswd -xWD "$ADMIN" -y "$PASSWDFILE" "$who" -T "$newpasswdfile"
done

