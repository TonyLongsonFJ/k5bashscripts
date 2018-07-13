#!/bin/bash
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Author:      Tony Longson, 2018.
# Description: Lists all volumes attached to named K5 servers.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function displayUsage() {
    printf "\n$scriptname by Tony Longson (tony.longson@uk.fujitsu.com)\n"
    printf "\n  (c) 2018 Fujitsu Services Ltd.\n"
    printf "\nBash shell script to list the volumes attached to named K5 server instances.\n"
    printf "\nOptional arguments:\n"
    printf "\n  --servernames <expression>"
    printf "\n      A filter to select particular server names, e.g. ???001* matches names where characters 4 to 6 contain 001.\n"
    . ./k5token.sh --help
}

function getLongestElement {
  #
  # Returns the longest element in the given array.
  # Note that if more than one element has that
  # length then the first one found is returned.
  #
  local i thisitem longestitem maxleng thisleng maxitem
  declare -a inputarray=("${!1}")
  maxleng=0
  maxitem=$((${#inputarray[@]}-1))
  for (( i=0; i<=maxitem; i++ )); do
    thisitem=${inputarray[i]}
    thisleng=${#thisitem}
    if (( $thisleng > $maxleng )); then
      maxleng=$thisleng
      longestitem=$thisitem
    fi
  done
  eval $2=\$longestitem
}

function getArrayWidth {
  #
  # Returns the length of the longest item in the given array.
  #
  local item leng
  declare -a array=("${!1}")
  getLongestElement array[@] item
  leng=${#item}
  eval $2=\$leng
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

  declare -a srvNames volDevices volIds volNames volSizes volDescs
  declare i j vNum srvName srvId volId volName volDesc volSize
  echo
  srvNames[0]="Server Name"
  srvNames[1]="==========="
  volDevices[0]="Device"
  volDevices[1]="======"
  volIds[0]="Volume Identifier"
  volIds[1]="================="
  volNames[0]="Volume Name"
  volNames[1]="==========="
  volSizes[0]="Size (GB)"
  volSizes[1]="========="
  volDescs[0]="Description"
  volDescs[1]="==========="
  vNum=2
  for ((i=0; i < srvCount; i++)); do
    srvName=$(jq -j ".servers[$i].name" .k5servers.json)
    srvId=$(jq -j ".servers[$i].id" .k5servers.json)
    if [[ $srvName == $k5svrnamefilt ]]; then
      rm -f .k5servervolumes.json
      curl -ks -X GET \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -H "X-Auth-Token: $OS_AUTH_TOKEN" \
        "$COMPUTE/servers/$srvId/os-volume_attachments" > .k5servervolumes.json
      volCount=$(jq -j ".volumeAttachments|length" .k5servervolumes.json)
      if (( volCount < 1 )); then
        ((vNum++))
        srvNames[$vNum]=$srvName
        volDevices[$vNum]="none"
        volIds[$vNum]="n/a"
        volNames[$vNum]="n/a"
        volSizes[$vNum]="n/a"
        volDescs[$vNum]="n/a"
      else
        for ((j=0; j < volCount; j++)); do
          ((vNum++))
          volDevices[$vNum]=$(jq -j ".volumeAttachments[$j].device" .k5servervolumes.json)
          volIds[$vNum]=$(jq -j ".volumeAttachments[$j].volumeId" .k5servervolumes.json)
          rm -f .k5volumedetail.json
          curl -ks -X GET \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -H "X-Auth-Token: $OS_AUTH_TOKEN" \
            "$BLOCKSTORAGE/volumes/${volIds[vNum]}" > .k5volumedetail.json
          srvNames[$vNum]=$srvName
          volNames[$vNum]=$(jq -j ".volume|.display_name" .k5volumedetail.json)
          volDescs[$vNum]=$(jq -j ".volume|.display_description" .k5volumedetail.json)
          volSizes[$vNum]=$(jq -j ".volume|.size" .k5volumedetail.json)
        done
      fi
    fi
  done
  #
  # Find the required width of each data column to optimise output table layout.
  #
  getArrayWidth srvNames[@] sNameWidth
  getArrayWidth volDevices[@] vDevWidth
  getArrayWidth volIds[@] vIdWidth
  getArrayWidth volNames[@] vNameWidth
  getArrayWidth volSizes[@] vSizeWidth
  getArrayWidth volDescs[@] vDescWidth
  for ((i=0; i <= vNum; i++)); do
    printf "      %-${sNameWidth}s  %-${vDevWidth}s  %-${vIdWidth}s  %-${vNameWidth}s  %${vSizeWidth}s  %-${vDescWidth}s\n" "${srvNames[i]}" "${volDevices[i]}" "${volIds[i]}" "${volNames[i]}" "${volSizes[i]}" "${volDescs[i]}"
  done
  printf "\n"
