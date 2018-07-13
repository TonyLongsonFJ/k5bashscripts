#!/bin/bash
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Author:      Tony Longson, 2018.
# Description: Lists block storage snapshots in a K5 project.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function displayUsage() {
    printf "\n$scriptname by Tony Longson (tony.longson@uk.fujitsu.com)\n"
    printf "\n  (c) 2018 Fujitsu Services Ltd.\n"
    printf "\nBash shell script to list K5 block storage snapshot instances.\n"
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
  echo Getting the list of snapshots for project $K5_PROJECT ...
  echo
  rm -f .k5snapshots.json

  curl -ks -X GET \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "X-Auth-Token: $OS_AUTH_TOKEN" \
    "$BLOCKSTORAGE/snapshots/detail" > .k5snapshots.json

  snapCount=$(jq -j ".snapshots|length" .k5snapshots.json)

  if (( snapCount < 1 )); then
    echo
    echo No block storage instances were found for project $K5_PROJECT.
    return 1 2> /dev/null
    exit 1
  fi

  echo
  printf "      %-36s  %-36s  %4s  %s\n" "Snapshot Name" "Snapshot Identifier" "Size" "Description"
  printf "      %-36s  %-36s  %4s  %s\n" "=============" "===================" "====" "==========="
  printf "\n"
  declare i snapname snapid snapsize snapdesc
  for ((i=0; i < snapCount; i++)); do
    snapname=$(jq -j ".snapshots[$i].display_name" .k5snapshots.json)
    snapid=$(jq -j ".snapshots[$i].id" .k5snapshots.json)
    snapdesc=$(jq -j ".snapshots[$i].display_description" .k5snapshots.json)
    snapsize=$(jq -j ".snapshots[$i].size" .k5snapshots.json)
    printf "      %-36s  %-36s  %4d  %s\n" "$snapname" "$snapid" "$snapsize" "$snapdesc"
  done
  printf "\n"
