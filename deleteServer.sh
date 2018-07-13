#!/bin/bash
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Author:      Tony Longson, 2018.
# Description: Deletes a server from a K5 project.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function displayUsage() {
    printf "\n$scriptname by Tony Longson (tony.longson@uk.fujitsu.com)\n"
    printf "\n  (c) 2018 Fujitsu Services Ltd.\n"
    printf "\nBash shell script to delete a K5 server instance.\n"
    printf "\nOptional arguments:\n"
    printf "\n  --server <servername|serverid>"
    printf "\n      The K5 server name or ID. If not supplied, the user is prompted for one.\n"
    printf "\n  --force"
    printf "\n      Uses the 'force-deletion' option."
    . ./k5token.sh --help
}

  shopt -s extglob nocasematch
  if [[ "$scriptname" == "" ]]; then readonly scriptname=$(basename $BASH_SOURCE); fi

  declare k5_server_input response
  declare force_delete="n"

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
      -?(-)server)
         if (( optnum < $# )); then
           (( optnum++ ))
           k5_server_input="${!optnum}"
         fi
         ;;
      -?(-)force)
        force_delete="y"
        ;;
    esac
    (( optnum++ ))
  done

  . ./k5token.sh "$@" --defaultproject
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
  echo Server deletion
  echo
  echo Getting the list of servers for project $K5_PROJECT ...
  echo
  rm -f .k5servers.json

  curl -ks -X GET \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "X-Auth-Token: $OS_AUTH_TOKEN" \
    "$COMPUTE/servers/detail" > .k5servers.json

  declare srvCount=$(jq -j ".servers|length" .k5servers.json)

  if (( srvCount < 1 )); then
    echo
    echo No server instances were found for project $K5_PROJECT.
    return 1 2> /dev/null
    exit 1
  fi

  printf "\n"

  declare i p svrName svrId
  declare -a svrNames svrIds
  p=-1
  for ((i=0; i < srvCount; i++)); do
    svrName=$(jq -j ".servers[$i].name" .k5servers.json)
    svrId=$(jq -j ".servers[$i].id" .k5servers.json)
    svrNames[$i]="$svrName"
    svrIds[$i]="$svrId"
    #
    # If a server name was specified as a script argument, use the matching index instead of prompting.
    #
    if [[ $svrName == $k5_server_input || $svrId == $k5_server_input ]]; then
      p=$i
    fi
  done
  echo
  if (( p < 0 )); then
    getListChoice "Server Name" svrNames[@] p
    echo
  fi
  svrName="${svrNames[$p]}"
  svrId="${svrIds[$p]}"

  echo
  read -e -p "Type yes if you are sure you want to delete server $svrName :" response
  if [[ ! $response == "yes" ]]; then
    return 1 2> /dev/null
    exit 1
  fi

  echo "Deleting server $svrName ($svrId) ..."
  echo
  if [[ $force_delete == "y" ]]; then
    curl -X POST -iks -H "X-Auth-Token: $K5_PROJECT_TOKEN" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -d '{ "forceDelete": null }' \
      "$COMPUTE/servers/$svrId/action"
  else
    curl -X DELETE -iks -H "X-Auth-Token: $K5_PROJECT_TOKEN" "$COMPUTE/servers/$svrId"
  fi
