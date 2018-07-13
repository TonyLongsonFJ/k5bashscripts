#!/bin/bash
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Author:      Tony Longson, 2018.
# Description: Lists block storage instances in a K5 project.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function displayUsage() {
    printf "\n$scriptname by Tony Longson (tony.longson@uk.fujitsu.com)\n"
    printf "\n  (c) 2018 Fujitsu Services Ltd.\n"
    printf "\nBash shell script to list K5 block storage instances.\n"
    printf "\nOptional arguments:\n"
    . ./k5token.sh --help
}

  shopt -s extglob nocasematch
  if [[ "$scriptname" == "" ]]; then readonly scriptname=$(basename $BASH_SOURCE); fi

  #
  # Check for optional script arguments.
  #
  optnum=1
  while (( optnum <= $# )); do
    case "${!optnum}" in
      -?(-)h?(elp)|-?(-)\?)
        displayUsage
        return 1 2> /dev/null
        exit 1
        ;;
    esac
    (( optnum++ ))
  done

  . ./k5token.sh "$@"
  if [ "$OS_AUTH_TOKEN" = "" ]; then return 1 2> /dev/null; exit 1; fi

  #
  # Resume keystroke echo on exit.
  #
  trap "stty echo" RETURN
  #
  # Temporarily stop echoing user keystrokes.
  #
  stty -echo

  echo
  echo Getting the list of block storage instances for project $K5_PROJECT ...
  echo
  rm -f .k5volumes.json

  curl -ks -X GET \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "X-Auth-Token: $OS_AUTH_TOKEN" \
    "$BLOCKSTORAGE/volumes/detail" > .k5volumes.json

  volCount=$(jq -j ".volumes|length" .k5volumes.json)

  if (( volCount < 1 )); then
    echo
    echo No block storage instances were found for project $K5_PROJECT.
    return 1 2> /dev/null
    exit 1
  fi

  echo
  printf "      %-32s  %-36s  %4s  %s\n" "Volume Name" "Volume Identifier" "Size" "Description"
  printf "      %-32s  %-36s  %4s  %s\n" "===========" "=================" "====" "==========="
  printf "\n"
  declare i volname volid volsize voldesc
  for ((i=0; i < volCount; i++)); do
    volname=$(jq -j ".volumes[$i].display_name" .k5volumes.json)
    volid=$(jq -j ".volumes[$i].id" .k5volumes.json)
    voldesc=$(jq -j ".volumes[$i].display_description" .k5volumes.json)
    volsize=$(jq -j ".volumes[$i].size" .k5volumes.json)
    printf "      %-32s  %-36s  %4d  %s\n" "$volname" "$volid" "$volsize" "$voldesc"
  done
  printf "\n"
