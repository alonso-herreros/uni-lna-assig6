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
THOR="uid=thor,$AVENGERS"
HAWKEYE="uid=hawkeye,$AVENGERS"

GROOT="uid=groot,$GUARDIANS"
DRAX="uid=drax,$GUARDIANS"

# When possible, use the first example in a class as the accessing user and the
# last as the accessed entry

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
# `Random user`: `firstAppearance`
# `Random user`: `inMovie`
# `Héroe de los X-Men`: `species`
# `Héroe de los Vengadores`: `species`
# `Héroe de los Guardianes`: `species`
# `Mentor`: `species`
# `Héroe de los X-Men`: `snapped` (UNDEFINED, SHOULD SKIP)
# `Héroe de los Vengadores`: `snapped`
# `Héroe de los Guardianes`: `snapped`
# `Mentor de los X-Men`: `snapped`
# `Mentor de los Vengadores`: `snapped`
# `Mentor de los Guardianes`: `snapped`
# `Héroe`: `quote`
# `Mentor`: `quote`
# `Groot`: `quote`

WHAT_DNS=( "$CYCLOPS" "$HAWKEYE" "$DRAX" "$STARLORD" "$DRAX" \
    "$CYCLOPS" "$HAWKEYE" "$DRAX" "$PROFESSORX" "$NICKFURY" "$STARLORD" \
    "$STARLORD" "$DRAX" \
    "$CYCLOPS" "$HAWKEYE" "$DRAX" "$STARLORD" \
    "$CYCLOPS" "$HAWKEYE" "$DRAX" "$PROFESSORX" "$NICKFURY" "$STARLORD" \
    "$HAWKEYE" "$NICKFURY" "$GROOT" )
WHAT_ATTRS=( "userPassword" "roomNumber" "title" "mail" "telephoneNumber" \
    "cn" "cn" "cn" "cn" "cn" "cn" \
    "firstAppearance" "inMovie"
    "species" "species" "species" "species" \
    "snapped" "snapped" "snapped" "snapped" "snapped" "snapped" \
    "quote" "quote" "quote" )

# ---- Test abstraction ----
function test_ldap_access_array() {
    local self=0
    local as=
    local title=
    while [ -n "$1" ]; do case "$1" in
        -s | --self )
            self=1
            shift;;
        -S | --no-self )
            # Skip checks if accessing = accessed
            echo "no self"
            self=-1
            shift;;
        -D | --as )
            as="$2"
            shift 2;;
        -t | --title )
            title="$2"
            shift 2;;
        * ) break;; # No arg shift
    esac; done

    # If 'as' wasn't set and not using self, assume it's the first arg
    [ -z "$as" -a $self -ne 1 ] && as="$1" && shift
    local permissions=("$@")

    [ -n "$title" ] && echo "---- Testing $title ----"

    [ "$as" == "self" ] && self=1

    local fails=0
    for i in "${!permissions[@]}"; do
        local level="${permissions[$i]}"
        local to="${WHAT_DNS[$i]}"
        local attr="${WHAT_ATTRS[$i]}"
        [ $self -eq -1 ] && [ "$as" == "$to" ] && continue
        [ $self -eq 1 ] && as="$to"
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

# --- Run tests ---
# By self
# WARNING: avoid testing special privileged users like Prof. X.
test_ldap_access_array -t "Self Access" \
    --self W R- R- R- R-  R- R- R-  R- R- R-  - - \
    R- R- R-  R-   ? R- R-  R- R- R-   W W  W
fails=$((fails + $?))

# By admin
test_ldap_access_array -t "Admin Write" \
    "$ADMIN" W W W W W  W W W  W W W  W W \
    W W W  W   ? W W  W W W   W W  W
fails=$((fails + $?))

# By Mentors
test_ldap_access_array -t "Mentor Read 1" -S \
    "$NICKFURY" - R R R- R-  R- R- R-  R- R- R-  - - \
    - R- -  R-   ? R- -  - - -   R- R-  -
fails=$((fails + $?))
test_ldap_access_array -t "Mentor Read 2" -S \
    "$STARLORD" - R R R- R-  R- R- R-  R- R- R-  - - \
    - - R-  R-   ? - R-  - - -   R- R-  R-
fails=$((fails + $?))

# By specific people
test_ldap_access_array -t "Profesor X" \
    "$PROFESSORX" - W W W W  W W W  W W W  - - \
    R- R- R-  R-   ? R- R-  R- R- R-   W W  -
fails=$((fails + $?))

test_ldap_access_array -t "Nick Fury write Room Number" \
    "$NICKFURY" - W R- ? ?  ? ? ?  ? ? ?
fails=$((fails + $?))

test_ldap_access_array -t "Starlord write Title" \
    "$STARLORD" - R- W ? ?  ? ? ?  ? ? ?
fails=$((fails + $?))

# By heroes
test_ldap_access_array -t "X-Men read" \
    "$WOLVERINE" - - - R- R-  ? ? ?  ? ? ?  - - \
    R- - -  -   ? - -  R- - -   R- R-
fails=$((fails + $?))
test_ldap_access_array -t "Avengers read" \
    "$IRONMAN" - - - R- R-  ? ? ?  ? ? ?  - - \
    - R- -  -   ? R- -  - R- -   R- R-
fails=$((fails + $?))
test_ldap_access_array -t "Guardians read" \
    "$GROOT" - - - R- R-  ? ? ?  ? ? ?  - - \
    - - R-  -   ? - R-  - - R-   R- R-
fails=$((fails + $?))

# Groot quote read test by heroes (by mentors was tested already)
test_ldap_access_array -t "Groot quote deny 1" \
    "$IRONMAN" ? ? ? ? ?  ? ? ?  ? ? ?  ? ?  ? ? ?  ?   ? ? ?  ? ? ?   ? ?  -
fails=$((fails + $?))
test_ldap_access_array -t "Groot quote deny 2" \
    "$WOLVERINE" ? ? ? ? ?  ? ? ?  ? ? ?  ? ?  ? ? ?  ?   ? ? ?  ? ? ?   ? ?  -
fails=$((fails + $?))
test_ldap_access_array -t "Groot quote allow 1" \
    "$DRAX" ? ? ? ? ?  ? ? ?  ? ? ?  ? ?  ? ? ?  ?   ? ? ?  ? ? ?   ? ?  R-
fails=$((fails + $?))
test_ldap_access_array -t "Groot quote allow 2" \
    "$THOR" ? ? ? ? ?  ? ? ?  ? ? ?  ? ?  ? ? ?  ?   ? ? ?  ? ? ?   ? ?  R-
fails=$((fails + $?))

# Test report
[ $fails -eq 0 ] \
    && echo "==== Test collection Permissions: all passed ====" \
    || echo "!=== Test collection Permissions: $fails FAILED ===!"
