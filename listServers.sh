#!/bin/bash
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Author:      Tony Longson, 2018.
# Description: Lists servers in a K5 project.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function displayUsage() {
    printf "\n$scriptname by Tony Longson (tony.longson@uk.fujitsu.com)\n"
    printf "\n  (c) 2018 Fujitsu Services Ltd.\n"
    printf "\nBash shell script to list K5 server instances.\n"
    printf "\nOptional arguments:\n"
    printf "\n  --servernames <expression>"
    printf "\n      A filter to select particular server names, e.g. ???001* matches names where characters 4 to 6 contain 001.\n"
    . ./k5token.sh --help
}

  shopt -s extglob nocasematch
  if [[ "$scriptname" == "" ]]; then readonly scriptname=$(basename $BASH_SOURCE); fi

  k5svrnamefilt="*"
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
      -?(-)servernames)
         if (( optnum < $# )); then
           (( optnum++ ))
           k5svrnamefilt="${!optnum}"
         fi
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
  echo Getting the list of servers for project $K5_PROJECT ...
  echo
  rm -f .k5servers.json

  curl -ks -X GET \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "X-Auth-Token: $OS_AUTH_TOKEN" \
    "$COMPUTE/servers" > .k5servers.json

  srvCount=$(jq -j ".servers|length" .k5servers.json)

  if (( srvCount < 1 )); then
    echo
    echo No server instances were found for project $K5_PROJECT.
    return 1 2> /dev/null
    exit 1
  fi

  echo
  printf "      %-32s  %-36s\n" "Server Name" "Server Identifier"
  printf "      %-32s  %-36s\n" "===========" "================="
  printf "\n"
  declare i srvname srvid srvsize srvdesc
  for ((i=0; i < srvCount; i++)); do
    srvname=$(jq -j ".servers[$i].name" .k5servers.json)
    srvid=$(jq -j ".servers[$i].id" .k5servers.json)
    if [[ $srvname == $k5svrnamefilt ]]; then
      printf "      %-32s  %-36s\n" "$srvname" "$srvid"
    fi
  done
  printf "\n"
