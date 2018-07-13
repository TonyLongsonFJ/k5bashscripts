#!/bin/bash
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Author:      Tony Longson, 2018.
# Description: Creates a server in a K5 project.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#######
# WIP #
#######

# 1. CREATE Server
# 2. RENAME NIC
# 3. RENAME C: DRIVE
#

function displayUsage() {
    printf "\n$scriptname by Tony Longson (tony.longson@uk.fujitsu.com)\n"
    printf "\n  (c) 2018 Fujitsu Services Ltd.\n"
    printf "\nBash shell script to create a K5 server instance.\n"
    printf "\nOptional arguments:\n"
    printf "\n  --servername <servername>"
    printf "\n      The K5 server name. Required.\n"
    printf "\n  --type <servertype|serverflavour>"
    printf "\n      The K5 server type (e.g. S-1) or flavour code (e.g. $DEFAULT_FLAVOUR). Required.\n"
    printf "\n  --bootimage <UUID>"
    printf "\n      The boot image reference UUID to use for the server. Required if osimage not specified.\n"
    printf "\n  --ip4address <xxx.xxx.xxx.xxx>"
    printf "\n      The IPv4 address to assign to the server's network interface. Optional.\n"
    printf "\n  --maxcount <n>"
    printf "\n      The maximum number of instances of the server.\n"
    printf "\n  --mincount <n>"
    printf "\n      The minimum number of instances of the server.\n"
    printf "\n  --network <UUID>"
    printf "\n      The network reference UUID to use for the server. Optional.\n"
    printf "\n  --osimage <UUID>"
    printf "\n      The OS image reference UUID to use for the server. Optional if bootimage specified.\n"
    printf "\n  --admpassword <adminpassword>"
    printf "\n      The admin password for the server. Required.\n"
    printf "\n  --secgroup <security_group_name>"
    printf "\n      The security group to add the server to. Optional.\n"
    printf "\n  --volsize <size>"
    printf "\n      The size (in GB) to allocate to the boot image. Required if bootimage specified.\n"
    printf "\n  --zone <availability_zone>"
    printf "\n      The K5 availablity zone (default is $DEFAULT_AZ). Optional.\n"
    . ./k5token.sh --help
    printf "\nThe user will be prompted for any missing required properties.\n"
}

  shopt -s extglob nocasematch
  if [[ "$scriptname" == "" ]]; then readonly scriptname=$(basename $BASH_SOURCE); fi

  #
  # Set parameter defaults.
  #
  DEFAULT_AZ=uk-1a
  DEFAULT_FLAVOUR=1101

  VALID_GUID="^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
  declare k5az=$DEFAULT_AZ
  declare k5maxcount='1'
  declare k5mincount='1'
  declare k5bootimgid k5ip4addr k5nwid k5osimgid k5secgrp k5vmname k5type k5volsize
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
      -?(-)zone)
         if (( optnum < $# )); then
           (( optnum++ ))
           k5az="${!optnum}"
         fi
         ;;
      -?(-)servername)
         if (( optnum < $# )); then
           (( optnum++ ))
           k5vmname="${!optnum}"
         fi
         ;;
      -?(-)bootimage)
         if (( optnum < $# )); then
           (( optnum++ ))
           k5bootimgid="${!optnum}"
         fi
         if [[ $k5bootimgid == "" ]]; then
           printf "Invalid --bootimage value. Use --help for argument specifications."
           return 1 2> /dev/null
           exit 1
         fi
         ;;
      -?(-)ip4address)
         if (( optnum < $# )); then
           (( optnum++ ))
           k5ip4addr="${!optnum}"
         fi
         ;;
      -?(-)maxcount)
         if (( optnum < $# )); then
           (( optnum++ ))
           k5maxcount="${!optnum}"
         fi
         ;;
      -?(-)mincount)
         if (( optnum < $# )); then
           (( optnum++ ))
           k5mincount="${!optnum}"
         fi
         ;;
      -?(-)network)
         if (( optnum < $# )); then
           (( optnum++ ))
           k5nwid="${!optnum}"
         fi
         ;;
      -?(-)osimage)
         if (( optnum < $# )); then
           (( optnum++ ))
           k5osimgid="${!optnum}"
         fi
         ;;
      -?(-)admpassword)
        if (( optnum < $# )); then
          (( optnum++ ))
          k5admpwd="${!optnum}"
        fi
        ;;
      -?(-)secgrp)
         if (( optnum < $# )); then
           (( optnum++ ))
           k5secgrp="${!optnum}"
         fi
         ;;
      -?(-)volsize)
         if (( optnum < $# )); then
           (( optnum++ ))
           k5volsize="${!optnum}"
         fi
         if [[ ! $k5volsize =~ ^[1-9][0-9]*$ ]]; then
           printf "Invalid --volsize value. Use --help for argument specifications."
           return 1 2> /dev/null
           exit 1
         fi
         ;;
      -?(-)type)
         if (( optnum < $# )); then
           (( optnum++ ))
           k5type="${!optnum}"
         fi
         ;;
    esac
    (( optnum++ ))
  done

  if [[ $k5bootimgid != "" ]]; then
    if [[ $k5volsize == "" ]]; then
      printf "Bootimage specified, but volume size missing. Use --help for argument specifications."
      return 1 2> /dev/null
      exit 1
    fi
  fi

  . ./k5token.sh "$@"
  if [ "$OS_AUTH_TOKEN" = "" ]; then return 1 2> /dev/null; exit 1; fi

  until [ "$k5az" != "" ]; do
    printf "\n"
    read -e -p "Please confirm the availability zone to host the new VM:  " -i $DEFAULT_AZ k5az
  done

  until [ "$k5vmname" != "" ]; do
    printf "\n"
    read -e -p "Please enter the name of the VM to be created:            " k5vmname
  done

  until [[ $k5admpwd =~ ^[^\"]+$ ]]; do
    printf "\n"
    read -e -p "Please enter the management password for the new VM (double quotes not allowed):  " -s k5admpwd
    printf "\n"
  done

  k5flavour=""
  if [ "$k5type" != "" ]; then
    if [[ $k5type =~ ^[0-9]{4,}$ ]]; then
      #
      # If the server type argument is a number, use it as a flavour.
      #
      k5flavour=$k5type
      k5type=""
    fi
  fi

  if [ ! -f servertypes.txt ]; then
    #
    # The file containing all valid server flavours is missing. Create it silently.
    #
    . ./listFlavours.sh --quiet
  fi
  
  if [[ $k5flavour == "" ]]; then
    mapfile svrtypelist < servertypes.txt   # Read the server type list file into an array.
    declare -a svrtypes
    declare -a svrflavours
    declare -i j=0
    for ((i = 0; i < ${#svrtypelist[@]}; i++)); do
      item=${svrtypelist[i]}
      if [[ $item =~ ^[[:space:]]*([A-Za-z0-9-]+)[[:space:]]+([[:digit:]]{4,})[[:space:]]+([A-Za-z]+)[[:space:]]+([[:digit:]]+)[[:space:]]+([[:digit:]]+)[[:space:]]*$ ]]; then
        # Valid data line comprising server type, flavour, cpu speed, vcpu count and memory size.
        # Now make a summary line for the scrollable array of server types the user will pick from.
        svrLine="${BASH_REMATCH[2]} (type ${BASH_REMATCH[1]}, ${BASH_REMATCH[3],,} speed, ${BASH_REMATCH[4]} vCpus, ${BASH_REMATCH[5]}GB RAM)"
        svrflavours[$j]="${BASH_REMATCH[2]}"
        svrtypes[$j]="$svrLine"
        if [[ $k5type != "" ]]; then
          if [[ $k5type == ${BASH_REMATCH[1]} ]]; then
            k5flavour="${BASH_REMATCH[2]}"
          fi
        fi
        j+=1
      fi
    done

    until [[ $k5flavour =~ ^[0-9]{4,}$ ]]; do
      printf "\n"
      if (( j < 1 )); then
        #
        # No valid server list - just prompt for the flavour code.
        #
        read -e -p "Please enter the numeric server flavour code (enter ? to list options): " -i $DEFAULT_FLAVOUR k5flavour
        if [[ $k5flavour =~ \? ]]; then
          cat ./servertypes.txt
          # echo
          # for line in $(cat ./servertypes.txt); do
            # echo    $line
          # done
          echo
        else
          # Check if the flavour is in the list
          grep -cE '[^0-9]'$k5flavour'[^0-9]' servertypes.txt |grep -E '^1$' > /dev/null
          if [ $? != 0 ]; then
            #
            # Not a known flavour - force user to re-input
            #
            unset k5flavour
          fi
        fi
      else
        getListChoice "Server Flavour" svrtypes[@] j
        k5flavour=${svrflavours[j]}
      fi
    done
  fi

  until [[ $k5osimgid =~ $VALID_GUID ]]; do
    printf "\n"
    read -e -p "Please enter the GUID of the source OS image:        " k5osimgid
  done

  # printf "\nChosen flavour code is $k5flavour\n"

  imgidjson=''
  if [[ $k5osimgid != "" ]]; then
    imgidjson=', "imageRef": "'$k5osimgid'"'
    if [[ $k5bootimgid == "" ]]; then
      k5bootimgid=$k5osimgid
    fi
  fi
  azjson=', "availability_zone": "'$k5az'"'
  flavjson=', "flavorRef": "'$k5flavour'"'
  metajson=', "metadata": {'
  apwdjson=''
  if [[ $k5admpwd != "" ]]; then
    metajson=$metajson'"admin_pass": "'$k5admpwd'", '
    apwdjson=', "adminPass": "'$k5admpwd'"'
  fi
  metajson=$metajson'"fcx.autofailover": "true"}'
  blockdevjson=''
  if [[ $k5bootimgid != "" ]]; then
    blockdevjson=', "block_device_mapping_v2": [ {"boot_index": "0", "uuid": "'$k5bootimgid'", "volume_size": "'$k5volsize'", "device_name": "/dev/vda", "source_type": "image", "destination_type": "volume", "delete_on_termination": "true"} ]'
  fi
  countjson=', "max_count": '$k5maxcount', "min_count": '$k5mincount
  nwjson=''
  if [[ $k5nwid != "" ]]; then
    nwjson=', "networks": [ {"uuid": "'$k5nwid'"} ]'
  fi
  sgjson=''
  if [[ $k5secgrp != "" ]]; then
    sgjson=', "security_groups": [ {"name": "'$k5secgrp'"} ]'
  fi

  ip4json=''
  if [[ $k5ip4addr != "" ]]; then
    ip4json=', "accessIPv4": "'$k5ip4addr'"'
  fi

  curlJSON='{"server": {"name": "'$k5vmname'"'$azjson$flavjson$imgidjson$metajson$blockdevjson$apwdjson$sgjson$countjson$nwjson$ip4json'}, "os:scheduler_hints": {"fcx.dedicated": "true"}}'
  curlURL="$COMPUTE/servers"
  curlAuthHdr="X-Auth-Token: $OS_AUTH_TOKEN"
  curlContHdr="Content-Type: application/json"
  printf "\nRequest JSON:\n"
  echo $curlJSON | jq .
  printf "\nEnd of Request JSON\n"

  curl -isS --trace-ascii .curltrace "${curlURL}" -X POST -H "${curlAuthHdr}" -H "${curlContHdr}" -d "${curlJSON}" > .k5CSResponse
