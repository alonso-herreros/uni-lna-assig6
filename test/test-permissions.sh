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

# ---- Info ----
# Whats:
# `Random user`: `userPassword`
# `Vengadores`: `roomNumber`
# `Guardianes`: `title`
# `Mentores`: `mail`
# `Héroes`: `mail`, `telephoneNumber`
# `Héroe de los X-Men`: `cn`
# `Héroe de los Vengadores`: `cn`
# `Héroe de los Guardianes`: `cn`
# `Mentor de los X-Men`: `cn`
# `Mentor de los Vengadores`: `cn`
# `Mentor de los Guardianes`: `cn`

WHAT_DNS=( "$WOLVERINE" "$IRONMAN" "$GROOT" "$STARLORD" "$GROOT" \
    "$CYCLOPS" "$HAWKEYE" "$DRAX" "$PROFESSORX" "$NICKFURY" "$STARLORD" )
WHAT_ATTRS=( "userPassword" "roomNumber" "title" "mail" "telephoneNumber" \
    "cn" "cn" "cn" "cn" "cn" "cn" )

# ---- Test abstraction ----
function test_ldap_access_array() {
    local as=
    local title=
    while [ -n "$1" ]; do case "$1" in
        -D | --as )
            as="$2"
            shift 2;;
        -t | --title )
            title="$2"
            shift 2;;
        * ) break;; # No arg shift
    esac; done

    # If 'as' wasn't set, assume it's the first arg
    [ -z "$as" ] && as="$1" && shift
    local permissions=("$@")

    [ -n "$title" ] && echo "---- Testing $title ----"

    local fails=0
    for i in "${!permissions[@]}"; do
        local level="${permissions[$i]}"
        local to="${WHAT_DNS[$i]}"
        local attr="${WHAT_ATTRS[$i]}"
        _test_ldap_access "$level" -D "$as" -b "$to" -a "$attr"
        [ $? -ne 0 ] && ((fails++))
    done

    if [ -n "$title" ]; then
        [ $fails -eq 0 ] \
            && echo "---- Test $title: all passed ----" \
            || echo "!!-- Test $title: $fails FAILED--!!"
        echo ""
    fi

    return $fails
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


# Test header
echo "==== Testing collection: Permissions ===="

# INFO: 'what' order
# `Random user`: `userPassword`
# `Vengadores`: `roomNumber`
# `Guardianes`: `title`
# `Mentores`: `mail`
# `Héroes`: `mail`, `telephoneNumber`
# `Héroe de los X-Men`: `cn`
# `Héroe de los Vengadores`: `cn`
# `Héroe de los Guardianes`: `cn`
# `Mentor de los X-Men`: `cn`
# `Mentor de los Vengadores`: `cn`
# `Mentor de los Guardianes`: `cn`

# --- Run tests ---
# By admin
test_ldap_access_array -t "Admin Write" \
    "$ADMIN" W W W W W  W W W  W W W
fails=$((fails + $?))

# By Mentors
test_ldap_access_array -t "Mentor Read" \
    "$STARLORD" - R R R R  R R R  R R R
fails=$((fails + $?))

# # By specific people
# test_ldap_access_array -t "Profesor X Write" \
#     "$PROFESSORX" - W W W W  W W W  W W W
# fails=$((fails + $?))

# test_ldap_access_array -t "Nick Fury write Room Number" \
#     "$NICKFURY" - W R R R  R R R  R R R
# fails=$((fails + $?))

# test_ldap_access_array -t "Starlord write Title" \
#     "$STARLORD" - R W R R  R R R  R R R
# fails=$((fails + $?))

# # By heroes
# test_ldap_access_array -t "Hero read general" \
#     "$WOLVERINE" - - - R R  ? - -  ? ? ?
# fails=$((fails + $?))

# # Between heroes in the same team, plus their mentors
# test_ldap_access_array -t "Hero read general" \
#     "$WOLVERINE" - - - R R  R - -  R - -
# fails=$((fails + $?))
# test_ldap_access_array -t "Hero read general" \
#     "$IRONMAN" - - - R R  - R -  - R -
# fails=$((fails + $?))
# test_ldap_access_array -t "Hero read general" \
#     "$GROOT" - - - R R  - - R  - - R
# fails=$((fails + $?))

# Test report
[ $fails -eq 0 ] \
    && echo "==== Test collection Permissions: all passed ====" \
    || echo "!=== Test collection Permissions: $fails FAILED ===!"
