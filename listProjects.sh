#!/bin/bash
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Author:      Tony Longson, 2018.
# Description: Lists the projects within a K5 contract.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function displayUsage() {
    printf "\n$scriptname by Tony Longson (tony.longson@uk.fujitsu.com)\n"
    printf "\n  (c) 2018 Fujitsu Services Ltd.\n"
    printf "\nBash shell script to list projects within a K5 contract.\n"
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

  . ./k5token.sh "$@" --defaultproject
  if [ "$K5_CONTRACT_TOKEN" = "" ]; then return 1 2> /dev/null; exit 1; fi

  #
  # Resume keystroke echo on exit.
  #
  trap "stty echo" RETURN
  #
  # Temporarily stop echoing user keystrokes.
  #
  stty -echo

  echo Project list for contract $K5_CONTRACT
  echo

  curl -ks -X GET \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "X-Auth-Token: $K5_CONTRACT_TOKEN" \
    "$K5_USERS_URL/$K5_USER_ID/projects" > .k5projects.json

  K5_PROJECT_COUNT=$(jq -j ".projects|length" .k5projects.json)

  if (( K5_PROJECT_COUNT < 1 )); then
    echo
    echo No projects were found for contract $K5_CONTRACT.
    popd > /dev/null
    return 1 2> /dev/null
    exit 1
  fi

  echo
  printf "      %-32s  %-32s  %s\n" "Project Name" "Project Identifier" "Description"
  printf "      %-32s  %-32s  %s\n" "============" "==================" "==========="
  printf "\n"
  declare i projname projid projdesc
  for ((i=0; i < K5_PROJECT_COUNT; i++)); do
    projname=$(jq -j ".projects[$i].name" .k5projects.json)
    projid=$(jq -j ".projects[$i].id" .k5projects.json)
    projdesc=$(jq -j ".projects[$i].description" .k5projects.json)
    printf "      %-32s  %-32s  %s\n" "$projname" "$projid" "$projdesc"
  done
  printf "\n"
