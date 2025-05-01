#!/usr/bin/env bash

PASSWORD_DIR="passwords"

ADMIN="cn=admin,dc=marvel,dc=com"
PASSWDFILE="$PASSWORD_DIR/$ADMIN"

for newpasswdfile in $PASSWORD_DIR/*,dc=com; do
    who="$(basename $newpasswdfile)"

    # Skip if this is admin
    case "$who" in "cn=admin"* ) continue;; esac

    echo "Setting password for '$who'"
    ldappasswd -xWD "$ADMIN" -y "$PASSWDFILE" -S "$who" -T "$newpasswdfile"
done

