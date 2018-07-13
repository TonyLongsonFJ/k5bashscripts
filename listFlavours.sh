#!/bin/bash
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Author:      Tony Longson, 2018.
# Description: Lists all K5 flavours.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function displayUsage() {
    printf "\n$scriptname by Tony Longson (tony.longson@uk.fujitsu.com)\n"
    printf "\n  (c) 2018 Fujitsu Services Ltd.\n"
    printf "\nBash shell script to list K5 server flavours.\n"
    printf "\nOptional arguments:\n"
    printf "\n  --quiet"
    printf "\n      Don't list the flavour information, just create the local list file.\n"
    . ./k5token.sh --help
}

  shopt -s extglob nocasematch
  if [[ "$scriptname" == "" ]]; then readonly scriptname=$(basename $BASH_SOURCE); fi

  declare silentMode=0
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
      -?(-)quiet)
        silentMode=1
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

  if (( silentMode == 0 )); then
    echo
    echo Getting the list of K5 flavours ...
    echo
  fi
  rm -f .k5flavours.json

  curl -ks -X GET \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "X-Auth-Token: $OS_AUTH_TOKEN" \
    "$COMPUTE/flavors/detail" > .k5flavours.json

  flavCount=$(jq -j ".flavors|length" .k5flavours.json)

  if (( flavCount < 1 )); then
    if (( silentMode == 0 )); then
      echo
      echo No server flavours were found.
    fi
    return 1 2> /dev/null
    exit 1
  fi

  # jq . .k5flavours.json

  rm servertypes.txt
  echo>servertypes.txt
  echo>>servertypes.txt
  printf "      %-10s  %-10s  %-8s  %-8s  %s\n" "Server" "Flavour" " CPU"  "vCPU"  " GB"  >>servertypes.txt
  printf "      %-10s  %-10s  %-8s  %-8s  %s\n" " Type"  " Code "  "Speed" "Count" " RAM" >>servertypes.txt
  printf "      %-10s  %-10s  %-8s  %-8s  %s\n" "======" "=======" "=====" "=====" "====" >>servertypes.txt
  printf "\n" >>servertypes.txt
  declare i flavType flavCode flavRam flavCpus flavSpeed
  for ((i=0; i < flavCount; i++)); do
    flavType=$(jq -j ".flavors[$i].name" .k5flavours.json)
    flavCode=$(jq -j ".flavors[$i].id" .k5flavours.json)
    flavRam=$(jq -j ".flavors[$i].ram" .k5flavours.json)
    flavRam=$(jq -j -n $flavRam/1024) # Convert from MB to GB.
    flavCpus=$(jq -j ".flavors[$i].vcpus" .k5flavours.json)
    if (( flavCode >= 2000 )); then
      flavSpeed='High'
    else
      flavSpeed='Std'
    fi
    printf "       %-10s  %-10s  %-8s %4d  %8s\n" "$flavType" "$flavCode" "$flavSpeed" "$flavCpus" "$flavRam" >>servertypes.txt
  done
  printf "\n" >>servertypes.txt
  if (( silentMode == 0 )); then
    cat servertypes.txt
  fi
