#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib/ldap_test_utils.sh"

# ==== Usage ====
USAGE="
Usage: $0 [-p PASSWORD_DIR]
       $0 -h

OPTIONS

  -p, --passwords PASSWORD_DIR  Read passwords from files in the specified
                                directory. The file names are expected to be
                                the 'cn' of the entities whose password is
                                stored inside. Defaults to './passwords'.

  -h, --help                    Show this message and exit
"

OPTSTRING="hp:"
OPTSTRING_LONG="help,passwords:"

function Help() {
    echo "$USAGE"
}

# ==== Specifics ====
# ---- Constants ----
ROOT="dc=marvel,dc=com"
ADMIN="cn=admin,$ROOT"
MENTORS="ou=Mentores,$ROOT"
TEAMS="ou=Equipos,$ROOT"
XMEN="ou=XMen,$TEAMS"
AVENGERS="ou=Vengadores,$TEAMS"
GUARDIANS="ou=GuardianesDeLaGalaxia,$TEAMS"

PROFESSORX="uid=profesorx,$MENTORS"
NICKFURY="uid=nickfury,$MENTORS"
STARLORD="uid=starlord,$MENTORS"

WOLVERINE="uid=wolverine,$XMEN"
CYCLOPS="uid=ciclope,$XMEN"

IRONMAN="uid=ironman,$AVENGERS"
HAWKEYE="uid=hawkeye,$AVENGERS"

GROOT="uid=groot,$GUARDIANS"
DRAX="uid=drax,$GUARDIANS"

# ---- Test admin write all permission ----
function test_admin_write() {
    user_hero="uid=hawkeye,ou=Vengadores,ou=Equipos,dc=marvel,dc=com"
    _test_ldap_write --as "$ADMIN" --to "$user_hero" --attr roomNumber
}

# ==== Argument parsing ====
function args() {
    local options=$(getopt -o "$OPTSTRING" --long "$OPTSTRING_LONG" -- "$@")
    eval set -- "$options"

    while true; do
        case "$1" in
            -h | --help)
                Help
                exit 0;;
            -p | --passwords)
                PASSWORD_DIR="$2"
                shift 2;;
            --)
                shift
                break;;
        esac
    done
}

# ==== Main flow ====

# Options and defaults
PASSWORD_DIR="passwords"

# Parse args, setting options
args "$@"

test_admin_write
