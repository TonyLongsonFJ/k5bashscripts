#!/bin/bash
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Author:      Tony Longson, 2018.
# Description: Creates a firewall rule within a K5 contract.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function displayUsage() {
    printf "\n$scriptname by Tony Longson (tony.longson@uk.fujitsu.com)\n"
    printf "\n  (c) 2018 Fujitsu Services Ltd.\n"
    printf "\nBash shell script to create a firewall rule in a K5 project.\n"
    printf "\nOptional arguments:\n"
    printf "\n  --action  allow|deny"
    printf "\n      What type of rule this is, allow or deny. The default is $FWR_ACTION.\n"
    printf "\n  --destaddr <cidr>"
    printf "\n       The new firewall rule destination IP CIDR, e.g. '6.7.8.9/20'.\n"
    printf "\n  --destport <number>"
    printf "\n       The new firewall rule destination IP port, e.g. '6789'.\n"
    printf "\n  --protocol any|icmp|tcp|udp"
    printf "\n      The new firewall rule protocol. Default is $FWR_PROT.\n"
    printf "\n  --rulename <name>"
    printf "\n       The new firewall rule name, e.g. 'Allow WSUS traffic inbound'.\n"
    printf "\n  --srcaddr <cidr>"
    printf "\n       The new firewall rule source IP CIDR, e.g. '1.2.3.4/20'.\n"
    printf "\n  --srcport <number>"
    printf "\n       The new firewall rule source IP port, e.g. '1234'.\n"
    printf "\n  --zone <name>"
    printf "\n      The availability zone. The default is $FWR_AZ.\n"
    . ./k5token.sh --help
}

  shopt -s extglob nocasematch
  if [[ "$scriptname" == "" ]]; then readonly scriptname=$(basename $BASH_SOURCE); fi

  #
  # Set parameter defaults.
  #
  FWR_ACTION="allow"
  FWR_AZ=uk-1a
  FWR_PROT=any

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
      -?(-)action)
         if (( optnum >= $# )); then displayUsage; return 1 2> /dev/null ; exit 1; fi
         (( optnum++ ))
         FWR_ACTION="${!optnum,,}"
         ;;
      -?(-)destaddr)
         if (( optnum >= $# )); then displayUsage; return 1 2> /dev/null ; exit 1; fi
         (( optnum++ ))
         FWR_DEST="${!optnum}"
         ;;
      -?(-)destport)
         if (( optnum >= $# )); then displayUsage; return 1 2> /dev/null ; exit 1; fi
         (( optnum++ ))
         FWR_DEST_PORT="${!optnum}"
         ;;
      -?(-)protocol)
         if (( optnum >= $# )); then displayUsage; return 1 2> /dev/null ; exit 1; fi
         (( optnum++ ))
         FWR_PROT="${!optnum}"
         ;;
      -?(-)rulename)
         if (( optnum >= $# )); then displayUsage; return 1 2> /dev/null ; exit 1; fi
         (( optnum++ ))
         FWR_NAME="${!optnum}"
         ;;
      -?(-)srcaddr)
         if (( optnum >= $# )); then displayUsage; return 1 2> /dev/null ; exit 1; fi
         (( optnum++ ))
         FWR_SOURCE="${!optnum}"
         ;;
      -?(-)srcport)
         if (( optnum >= $# )); then displayUsage; return 1 2> /dev/null ; exit 1; fi
         (( optnum++ ))
         FWR_SOURCE_PORT="${!optnum}"
         ;;
      -?(-)zone)
         if (( optnum >= $# )); then displayUsage; return 1 2> /dev/null ; exit 1; fi
         (( optnum++ ))
         FWR_AZ="${!optnum}"
         ;;
    esac
    (( optnum++ ))
  done

  . ./k5token.sh "$@"
  if [ "$OS_AUTH_TOKEN" = "" ]; then return 1 2> /dev/null; exit 1; fi

  echo
  echo Firewall rule creation
  echo

  if [ "$FWR_ACTION" = "" ]; then
    read -e -p "Please enter the new firewall rule action (allow or deny): " -i "allow" FWR_ACTION
  fi

  FWR_ACTION=${FWR_ACTION,,}    # Force to lowercase.
  FWR_ACTION=${FWR_ACTION// /}  # Remove any blanks.
  if [[ ! "$FWR_ACTION" =~ ^(allow|deny)$ ]]; then
    echo
    echo "Invalid action. Exiting."
    echo
    exit 1
  fi

  if [ "$FWR_AZ" = "" ]; then
    read -e -p "Please enter the new firewall rule availability zone: " -i "$FWR_AZ" FWR_AZ
    if [ "$FWR_AZ" = "" ]; then
      echo
      echo "Availability zone cannot be blank. Exiting."
      echo
      exit 1
    fi
  fi

  if [ "$FWR_PROT" = "" ]; then
    read -e -p $'Please enter the new firewall rule protocol (tcp, udp, icmp or any): \e[7m' -i "any" FWR_PROT
    echo -en "\e[0m"
  fi

  FWR_PROT=${FWR_PROT,,}
  FWR_PROT=${FWR_PROT// /}
  if [[ ! "$FWR_PROT" =~ ^(tcp|udp|icmp|any)$ ]]; then
    echo
    echo "Invalid rule protocol. Exiting."
    echo
    exit 1
  fi

  if [ "$FWR_SOURCE" = "" ]; then
    read -e -p $'Please enter the new firewall rule source IP CIDR (e.g. 1.2.3.4/20): \e[7m' FWR_SOURCE
    echo -en "\e[0m"
  fi

  if [ "$FWR_SOURCE_PORT" = "" ]; then
    read -e -p $'Please enter the new firewall rule source IP PORT (e.g. 1234): \e[7m' FWR_SOURCE_PORT
    echo -en "\e[0m"
  fi

  if [ "$FWR_DEST" = "" ]; then
    read -e -p $'Please enter the new firewall rule destination IP CIDR (e.g. 1.2.3.4/20): \e[7m' FWR_DEST
    echo -en "\e[0m"
  fi

  if [ "$FWR_DEST_PORT" = "" ]; then
    read -e -p $'Please enter the new firewall rule destination IP PORT (e.g. 1234): \e[7m' FWR_DEST_PORT
    echo -en "\e[0m"
  fi

  if [ "$FWR_NAME" = "" ]; then
    FWR_ACTION_CAMEL=$(printf $FWR_ACTION|sed -e 's/.*/\L&/;s/^./\U&/')
    FWR_PROT_UCASE=$(printf $FWR_PROT|sed -e 's/.*/\U&/')
    read -e -p $'Please enter the new firewall rule name: \e[7m' -i "$FWR_ACTION_CAMEL"_"$PROT_UCASE"_"$FWR_SOURCE_PORT" FWR_NAME
    echo -en "\e[0m"
    if [ "$FWR_NAME" = "" ]; then
      echo
      echo "No firewall rule name supplied. Exiting."
      echo
      exit 1
    fi
  fi

  echo
  echo "Creating Firewall Rule $FWR_NAME ..."
  echo

  srcipjson=''
  if [ "$FWR_SOURCE" != "" ]; then
    srcipjson=', "source_ip_address": "'$FWR_SOURCE'"'
  fi

  srcportjson=''
  if [ "$FWR_SOURCE_PORT" != "" ]; then
    srcportjson=', "source_port": "'$FWR_SOURCE_PORT'"'
  fi

  destipjson=''
  if [ "$FWR_DEST" != "" ]; then
    destipjson=', "destination_ip_address": "'$FWR_DEST'"'
  fi

  destportjson=''
  if [ "$FWR_DEST_PORT" != "" ]; then
    destportjson=', "destination_port": "'$FWR_DEST_PORT'"'
  fi

  FWR_JSON='{"firewall_rule": { "name": "'$FWR_NAME'" ,"action": "'$FWR_ACTION'"'$srcipjson$srcportjson$destipjson$destportjson', "protocol": "'$FWR_PROT'", "availability_zone": "'$FWR_AZ'" }}'
  # echo curl -X POST -k -s $NETWORK/v2.0/fw/firewall_rules -H "X-Auth-Token: $OS_AUTH_TOKEN" -H "Content-Type: application/json" -d "$FWR_JSON"
  curl -X POST -k -s $NETWORK/v2.0/fw/firewall_rules -H "X-Auth-Token: $OS_AUTH_TOKEN" -H "Content-Type: application/json" -d "$FWR_JSON" | jq .
  echo
