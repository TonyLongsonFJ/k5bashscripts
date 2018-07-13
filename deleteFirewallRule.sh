#!/bin/bash
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Author:      Tony Longson, 2018.
# Description: Deletes a firewall rule from a K5 project.
#              If attached to a firewall policy, detaches it.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function displayUsage() {
    printf "\n$scriptname by Tony Longson (tony.longson@uk.fujitsu.com)\n"
    printf "\n  (c) 2018 Fujitsu Services Ltd.\n"
    printf "\nBash shell script to delete a firewall rule from a K5 project.\n"
    printf "\nOptional arguments:\n"
    printf "\n  -n <rulename>, --name <rulename>, --rulename <rulename>"
    printf "\n      The name of the firewall rule to delete. If not supplied,"
    printf "\n      the user is prompted to select one of the existing rules.\n"
    . ./k5token.sh --help
}

  shopt -s extglob nocasematch
  if [[ "$scriptname" == "" ]]; then readonly scriptname=$(basename $BASH_SOURCE); fi

  FWR_NAME_INPUT=""

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
      -?(-)?(rule)n?(ame))
         if (( optnum >= $# )); then displayUsage; return 1 2> /dev/null ; exit 1; fi
         (( optnum++ ))
         FWR_NAME_INPUT="${!optnum}"
         ;;
    esac
    (( optnum++ ))
  done

  . ./k5token.sh "$@"
  if [ "$OS_AUTH_TOKEN" = "" ]; then return 1 2> /dev/null; exit 1; fi

  echo
  echo Firewall rule deletion
  echo
  echo Getting the list of firewall rules for project $K5_PROJECT ...

  declare fwURL="$NETWORK/v2.0/fw"
  rm -f .k5fwrules.json

  curl -ks -X GET \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "X-Auth-Token: $OS_AUTH_TOKEN" \
    "$fwURL/firewall_rules" > .k5fwrules.json

  declare fwRuleCount=$(jq -j ".firewall_rules|length" .k5fwrules.json)

  if (( fwRuleCount < 1 )); then
    echo
    echo No firewall rules were found for project $K5_PROJECT.
    rm -f .k5fwrules.json
    return 1 2> /dev/null
    exit 1
  fi

  declare i j p fwrName fwrId fwrPolId
  declare -a fwrNames fwrIds fwrPolIds
  p=-1
  for ((i=0; i < fwRuleCount; i++)); do
    fwrName=$(jq -j ".firewall_rules[$i].name" .k5fwrules.json)
    fwrId=$(jq -j ".firewall_rules[$i].id" .k5fwrules.json)
    fwrPolId=$(jq -j ".firewall_rules[$i].firewall_policy_id" .k5fwrules.json)
    fwrNames[$i]="$fwrName"
    fwrIds[$i]="$fwrId"
    fwrPolIds[$i]="$fwrPolId"
    #
    # If a firewall rule name was specified as a script argument, use the matching index instead of prompting.
    #
    if [ "$fwrName" = "$FWR_NAME_INPUT" ]; then
      p=$i
    fi
  done
  echo
  if (( p < 0 )); then
    getListChoice "Firewall Rule Name" fwrNames[@] p
    echo
  fi
  fwrName="${fwrNames[$p]}"
  fwrId="${fwrIds[$p]}"
  fwrPolId="${fwrPolIds[$p]}"

  if [ "$fwrPolId" = "" ]; then
    echo "Firewall rule $fwrId is not attached to a firewall policy. No need to detach it."
    echo
  else
    echo "Firewall rule $fwrId is attached to firewall policy $fwrPolId. Detaching it ..."
    echo
    fwrDetachJson='{"firewall_rule_id": "'$fwrId'"}'
    curl -iks --trace-ascii .curltrace -X PUT -H "X-Auth-Token: $OS_AUTH_TOKEN" -H "Content-Type: application/json" -H "Accept: application/json" -d "$fwrDetachJson" "$fwURL/firewall_policies/$fwrPolId/remove_rule"
  fi

  echo "Deleting firewall rule $fwrId ..."
  echo
  curl -X DELETE -iks -H "X-Auth-Token: $OS_AUTH_TOKEN" "$fwURL/firewall_rules/$fwrId"
  rm -f .k5fwrules.json
