#!/bin/bash
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Author:      Tony Longson, 2018.
# Description: Lists block storage images in a K5 site.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function displayUsage() {
    printf "\n$scriptname by Tony Longson (tony.longson@uk.fujitsu.com)\n"
    printf "\n  (c) 2018 Fujitsu Services Ltd.\n"
    printf "\nBash shell script to list K5 block storage images in a K5 site.\n"
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
  echo Getting the list of images for site $K5_SITE ...
  echo
  rm -f .k5images.json

  curl -ks -X GET \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "X-Auth-Token: $OS_AUTH_TOKEN" \
    "https://image.$K5_SITE/v2/images" > .k5images.json

  imgCount=$(jq -j ".images|length" .k5images.json)

  if (( $imgCount < 1 )); then
    echo
    echo No block storage instances were found for project $K5_PROJECT.
    return 1 2> /dev/null
    exit 1
  fi

  echo
  printf "      %-36s  %s\n" "Image Name" "Image Identifier"
  printf "      %-36s  %s\n" "==========" "================"
  printf "\n"
  declare i imgname imgid 
  for ((i=0; i < imgCount; i++)); do
    imgname=$(jq -j ".images[$i].name" .k5images.json)
    imgid=$(jq -j ".images[$i].id" .k5images.json)
    printf "      %-36s  %s\n" "$imgname" "$imgid"
  done
  printf "\n"
