#!/bin/bash
#
# k5token.sh by Tony Longson (tony.longson@uk.fujitsu.com)
#
# (C) 2017, 2018 Fujitsu Services Ltd.
#
# Bash shell script to authenticate and scope to a selected K5 contract and project.
# Only prompts user if their authentication token has expired (or is about to).
# Remembers previous session details to minimise re-input.
#
# Tested on Ubuntu, MobaXTerm and Cygwin installations.
#
# To use the environment variables set by the script in subsequent scripts, run it as follows:
#
#   . ./k5token.sh
#
# Version  Date         Author                Description
# =======  =======      ====================  ====================================
#   1.0    04 Jul 2018  Tony Longson          Initial release.
#   1.1    10 Jul 2018  Tony Longson          Unset work variables on exit.
#

function displayUsage() {
  if [[ "$scriptname" == "$(basename $BASH_SOURCE)" ]]; then
      printf "\n$scriptname by Tony Longson (tony.longson@uk.fujitsu.com)\n"
      printf "\n  (c) 2017, 2018 Fujitsu Services Ltd.\n"
      printf "\nBash shell script to authenticate and scope to a K5 contract and project."
      printf "\nOnly prompts user if their authentication token has expired (or is about to)."
      printf "\nRemembers previous session details to minimise re-input.\n"
      printf "\nTested on Ubuntu, MobaXTerm and Cygwin installations.\n"
      printf "\nTo use variables set by the script in subsequent scripts, run it as follows:\n"
      printf "\n  . ./$scriptname\n"
      printf "\nOptional arguments:\n"
  fi
  printf "\n  -h, --help, -?"
  printf "\n      Show this help text.\n"
  printf "\n  -c <contract>, --contract <contract>"
  printf "\n      The K5 contract name. If not supplied, the user is prompted for one,"
  printf "\n      however the prompt will contain the last-used contract as a default.\n"
  printf "\n  -d, --default, --defaultproject"
  printf "\n      Scopes to the default project instead of prompting the user for one.\n"
  printf "\n  -p <password>, --password <password>"
  printf "\n      The user's password.\n"
  printf "\n  -s <project>, --scope <project>, --project <project>"
  printf "\n      The project name (not the ID) to scope to. If not supplied, the user is"
  printf "\n      prompted to scroll through the list of projects within the contract,"
  printf "\n      unless the -d option is specified.\n"
  printf "\n  -u <username>, --user <username>, --username <username>"
  printf "\n      The username to access the contract.\n"
  printf "\n  -v, --verbose"
  printf "\n      Show detailed progress messages.\n"
  printf "\nDependencies: The curl and jq commands must be available.\n"
}

function getInput {
  declare pwopt pwoptnum
  declare response=""
  until [ "$response" != "" ]; do
    if [[ "$2" =~ PASSWORD ]]; then
      read -e -p "$1" -s response
      printf "\n"
      if [ -f $pwfile ]; then
        pwopt=$(head -n 1 $pwfile)
      fi
      if [[ ! $pwopt =~ ^(always|never) ]]; then
         declare -a pwopts=("Save this time but ask again next time" "Don't save this time but ask again next time" "Always save and don't ask again" "Never save and don't ask again")
         getListChoice "password save option" pwopts[@] pwoptnum
         pwopt=${pwopts[pwoptnum]}
         printf "\n"
      fi
      printf "$pwopt\n" > $pwfile
      chmod 600 $pwfile
      if [[ $pwopt =~ ^(save|always) ]]; then
        printf "$response" |base64 >> $pwfile
      fi
    else
      read -e -p "$1" -i "$3" response
    fi
  done
  eval $2=\$response
}

function getListChoice {
  local blanks choice choicetext cols choicelines cuplines dataleng i item l promptfor textleng thisleng topitem
  stty -echo    # Turn off echoing of user keypresses.
  promptfor="$1"
  declare -a choices=("${!2}")
  dataleng=0
  topitem=$((${#choices[@]}-1))
  #
  # Get the length of the longest array entry.
  #
  for (( i=0; i<=topitem; i++ )); do
    item=${choices[i]}
    thisleng=${#item}
    if (( thisleng > dataleng )); then
      dataleng=$thisleng
      blanks=$item
    fi
  done

  blanks=$(echo -n "${blanks}"|sed -e 's/./ /g')    # Create a blank string as long as the longest entry.

  choicetext="Select $promptfor using cursor keys then press enter:"
  textleng=${#choicetext}
  choicelines=0
  cuplines=0
  i=0

  while [ 0 ]; do
    if (( i < 0 )); then i=0; fi
    if (( i > topitem )); then i=$topitem; fi
    choice=${choices[i]}
    cols=$(tput cols)    # We re-capture the window width each time in case the user re-sizes it.
    choicelines=$(((textleng+dataleng+1)/cols))
    for (( l=$cuplines; l > 0; l--)); do
      echo -en "\r\e[K\e[1A"    # Clear the current line then cursor up one line.
    done
    echo -en "\r\e[K"    # Clear the current line.
    if (( $choicelines > 0 )); then
      echo -en "\r$choicetext\r\n $blanks\e[${choicelines}A\r\e[s$choicetext\r\n \e[7m$choice\e[0m"    # Output the multi-line prompt.
      cuplines=$(( ((${#choice} + ( textleng > cols ? textleng : cols ) + 1 ) / cols) ))    # Record how many extra lines to clear next time the prompt appears.
    else
      echo -en "\r\e[s$choicetext $blanks\r$choicetext \e[7m$choice\e[0m"    # Output a single-line prompt.
      cuplines=0    # No extra lines to clear before next prompt.
    fi
    read -sn 1 inkey
    case "$inkey" in
      "5") let i=i-10     ;;    # Esc[5~ = Page Up = jump back ten entries
      "6") let i=i+10     ;;    # Esc[6~ = Page Down = jump forward ten entries
      "A") let i=i-1      ;;    # Esc[A  = Cursor Up = jump to previous entry
      "B") let i=i+1      ;;    # Esc[B  = Cursor Down = jump to next entry
      "F") let i=$topitem ;;    # Esc[F  = End = Jump to last entry
      "H") let i=0        ;;    # Esc[H  = Home = Jump to first entry
      "")  break          ;;
    esac
  done
  printf "\n"
  stty echo
  eval $3=\$i
}

function updateIdFile {
  #
  # First remove any existing line for the given name.
  #
  if [ -f .k5ids ]; then
    cat .k5ids|grep -v "^$1:" > .k5ids.new
    rm -f .k5ids && mv .k5ids.new .k5ids
  fi
  #
  # Now add the unique id for the name.
  #
  echo $1:$2>>.k5ids
}

function getObjectId {
  declare result=""
  if [ -f .k5ids ]; then
    result=$(awk 'BEGIN{IGNORECASE=1; FS=":"} /^'$1':/ {printf $2}' .k5ids)
  fi
  eval $2=\$result
  unset result
}

function splitTokenResponse {
  #
  # First separate the header and JSON content into separate files.
  #
  grep -Ei '^[a-z]' $1 > $1.header     # Put all lines beginning with a letter in the header file.
  grep -Ei '^[^a-z]' $1 > $1.json      # Put all lines beginning with a non-letter in the json file (should only be the one).
  #
  # Get the contract authorization token from the header file.
  # The awk extracts the token and the tr deletes the trailing CRLF characters.
  #
  awk 'BEGIN{IGNORECASE=1}/^x-subject-token:/ {print $2}' $1.header |tr -d '\n\r' > $1.token
  #
  # Delete the original combined file now we have separated its contents.
  #
  rm -f $1
}

function setProjectURLs {
  #
  # Following URLs are project-dependent and need to be refreshed on change of project.
  #
  COMPUTE='https://compute.'$K5_SITE'/v2/'$1
  DB='https://database.'$K5_SITE'/v1.0/'$1
  BLOCKSTORAGE='https://blockstorage.'$K5_SITE'/v1/'$1
  HOST_BLOCKSTORAGEV2=$BLOCKSTORAGE
  OBJECTSTORAGE='https://objectstorage.'$K5_SITE'/v1/AUTH_'$1
  ORCHESTRATION='https://orchestration.'$K5_SITE'/v1/'$1
}

function getK5Token {
  declare contract forceinput inputkey portalresponse projectid projectjson projectname pwfile pwopt readtoken token tokenfile tokenname tokentype returnvar username
  contract="$1"
  projectname="$2"
  projectid="$3"
  username="$4"
  returnvar="$5"
  if [ "$projectname" == "" ]; then
    tokentype="contract"
    tokenname="$contract"
  else
    tokentype="project"
    tokenname="$projectname"
  fi
  if [ "$tokenname" != "" ]; then
    tokenfile=.k5token.${tokenname}
  fi

  if [[ "$tokenfile" != "" && -f $tokenfile ]]; then
    #
    # Token file found. Check the age of the file. We can't use the "115 minutes ago" option as
    # it's not supported on all platforms (e.g. MobaXTerm, which uses the busybox date command).
    #
    if [[ $(date +%s -r $tokenfile) -gt $(date +%s --date="@$(($(date +%s) - 6900))") ]]; then
      #
      # Token file has more than five minutes left until it expires. Read the token.
      #
      readtoken=$(cat $tokenfile)
      if [[ "$readtoken" =~ $VALID_TOKEN ]]; then
        if [ "$verbose_mode" == "y" ]; then
          printf "A valid, non-expired token was found for $tokentype $tokenname.\n\n"
        fi
        token=$readtoken
      else
        printf "The K5 $tokentype token file did not contain a valid token.\n"
      fi
    else
      if [[ "$tokentype" == "contract" || "$verbose_mode" == "y" ]]; then
        printf "Your previous K5 $tokentype token is either about to expire or has already expired.\n\n"
      fi
    fi
  else
    if [ $verbose_mode == "y" ]; then
      printf "No existing K5 $tokentype token was found.\n\n"
    fi
  fi

  #
  # The following flag will be set to y if authentication fails, forcing the user
  # to re-enter the contract, username and password instead of reading them from
  # cache files, because we won't know which one(s) were mistyped.
  #
  forceinput="n"

  #
  # Prompt the user unless and until a valid token exists.
  #
  until [[ "$token" =~ $VALID_TOKEN ]]; do
    rm -f .k5${tokentype} .k5${tokentype}.*
    #
    # Only prompt for the items which haven't already been input or supplied as script arguments,
    #
    if [ "$k5_contract_input" = "" ]; then
      getInput "Please enter your K5 contract:  " k5_contract_input $contract
      if [ "$k5_contract_input" != "$contract" ]; then
        contract="$k5_contract_input"
        K5_CONTRACT="$contract"
        if [ "$tokentype" = "contract" ]; then tokenname="$contract"; fi
      fi
    fi
    if [ "$k5_username_input" = "" ]; then
      getInput "Please enter your K5 username:  " k5_username_input $username
      if [ "$k5_username_input" != "$username" ]; then
        username="$k5_username_input"
        K5_USERNAME="$username"
      fi
    fi
    #
    # Force the username to lowercase for the password cache file name as the user may not type it consistently.
    #
    pwfile=".k5pw.${contract}.${username,,}"
    #
    # If user previously chose to save their password, read it from the file.
    #
    if [ -f $pwfile ]; then
      pwdopt=$(head -n 1 $pwfile)
      if [[ $pwdopt =~ ^(save|always) ]]; then
        k5_password_input=$(tail -n 1 $pwfile|base64 -d)
      fi
    fi

    if [[ "$k5_password_input" == ""  || "$forceinput" == "y" ]]; then
      getInput "Please enter your K5 password:  " k5_password_input ""
    fi
    if [ "$verbose_mode" == "y" ]; then
      printf "\nRequesting authentication token for $tokentype $tokenname from $K5_TOKENS_URL ...\n\n"
    fi
    projectjson=""
    if [ "$projectid" != "" ]; then
      #
      # Build the optional project JSON data to inject into the request.
      #
      projectjson=', "scope": {"project": {"id": "'$projectid'" }}'
    fi
    tokenfile=.k5token.${tokenname}
    forceinput="n"
    K5_JSON='{"auth": {"identity": {"methods": ["password"], "password": {"user": {"domain": {"name": "'$k5_contract_input'"}, "name": "'$k5_username_input'", "password": "'$k5_password_input'"}}}'$projectjson'}}'
    #
    # If curl doesn't get a response from the portal, the output file will be zero bytes, so loop until it contains data.
    #
    portalresponse=0
    until [ $portalresponse -eq 1 ]; do
      curl -kisS --trace-ascii .curltrace -X POST -H "Content-Type: application/json" -H "Accept: application/json" -d "$K5_JSON" "$K5_TOKENS_URL" > .k5${tokentype}
      if [ -s .k5${tokentype} ]; then
        portalresponse=1
        splitTokenResponse .k5${tokentype}
        token=$(cat .k5${tokentype}.token)
        if [ "$token" == "" ]; then
          printf "\nAuthentication unsuccessful.\n"
          #
          # Allow re-input of password in case one of them was mistyped.
          #
          forceinput="y"
        else
          #
          # We've received a token from the portal. Get the ID fields from the json file using jq.
          #
          K5_CONTRACT_ID=$(jq -j '.token.project.domain.id' .k5${tokentype}.json)
          K5_USER_ID=$(jq -j '.token.user.id' .k5${tokentype}.json)
          updateIdFile "$K5_CONTRACT" "$K5_CONTRACT_ID"
          updateIdFile "$K5_USERNAME" "$K5_USER_ID"
          #
          # Rename the token file with its subject name.
          #
          mv -f .k5${tokentype}.token ${tokenfile}
        fi
      else
        printf "\nNo response from K5 portal - please check your network settings.\n\n"
        read -n1 -rp "Press A to abort or R to retry ... " inputkey
        if [[ $inputkey =~ [aA] ]]; then return 1 ; fi
        printf "\n"
      fi
    done
  done
  if [ "$tokentype" == "contract" ]; then
    K5_DEFAULT_PROJECT=$(jq -j '.token.project.name' .k5${tokentype}.json)
  fi

  k5_username_input=$K5_USERNAME
  k5_contract_input=$K5_CONTRACT
  if [ "$verbose_mode" == "y" ]; then
    printf "\nYour $tokentype authentication token is $token\n"
  fi
  eval $returnvar=\$token
  return 0
}

  shopt -s extglob nocasematch
  if [[ "$scriptname" == "" ]]; then readonly scriptname=$(basename $BASH_SOURCE); fi

  pushd ${BASH_SOURCE[0]%/*} > /dev/null #    Change working directory to the script folder.

  declare ttysave=$(stty -g)    # Save the terminal state so we can restore it on break.
  trap "stty $ttysave; exit" 0 1 2 3 15

  declare exitscript k5_contract_input k5_project_input k5_username_input k5_password_input lastcontract prereqsOk
  declare use_default_project="n"
  declare verbose_mode="n"
  #
  # If we're a "sourced" script we use return to exit, otherwise we use exit.
  #
  $(return > /dev/null 2>&1)
  if [ $? -eq 0 ]; then exitscript=return; else exitscript=exit; fi

  #
  # Clear the screen. Works on Cygwin, Ubuntu and MobaXTerm.
  #
  # clear && printf '\e[3J\ec'

  # printf "\n"
  K5_REGION='uk-1'
  K5_CLOUD='cloud.global.fujitsu.com'
  K5_SITE=$K5_REGION'.'$K5_CLOUD
  K5_IDENTITY_SITE='identity.'$K5_SITE
  K5_IDENTITY_URL='https://'$K5_IDENTITY_SITE
  K5_TOKENS_URL=$K5_IDENTITY_URL'/v3/auth/tokens'
  K5_USERS_URL=$K5_IDENTITY_URL'/v3/users'

  K5_USERNAME=""
  K5_CONTRACT=""
  if [ -f .k5lastuser ]; then K5_USERNAME=$(cat .k5lastuser); fi
  if [ -f .k5lastcontract ]; then
    lastcontract=$(cat .k5lastcontract)
    K5_CONTRACT="$lastcontract"
  fi

  VALID_TOKEN="^[0-9a-fA-F]{32}$"

  #
  # Look up the user, contract and project id's if we saved them in a previous run.
  #
  if [ "$K5_USERNAME" != "" ]; then getObjectId "$K5_USERNAME" K5_USER_ID; fi
  if [ "$K5_CONTRACT" != "" ]; then getObjectId "$K5_CONTRACT" K5_CONTRACT_ID; fi
  if [ "$K5_PROJECT" != "" ]; then getObjectId "$K5_PROJECT" K5_PROJECT_ID; fi

  #
  # Clear down legacy work variable values.
  #
  unset -v k5_contract_input k5_password_input k5_project_input k5_username_input use_default_project verbose_mode

  #
  # Check for the optional script arguments.
  #
  while (( $# > 0 )); do
    case "$1" in
      -?(-)h?(elp)|-?(-)\?)             displayUsage; $exitscript 1 ;;
      -?(-)c?(ontract))                 k5_contract_input="$2"; K5_CONTRACT="$2"; shift ;;
      -?(-)d?(efault?(project)))        use_default_project="y" ;;
      -?(-)p?(assword))                 k5_password_input="$2"; K5_PASSWORD="$2"; shift ;;
      -?(-)s?(cope)|-?(-)project)       k5_project_input="$2"; K5_PROJECT="$2"; shift ;;
      -?(-)u?(ser?(name)))              k5_username_input="$2"; K5_USERNAME="$2"; shift ;;
      -?(-)v?(erbose))                  verbose_mode="y" ;;
      #
      # Don't object to unknown options - they may be meant for the script we were called from.
      #
      # *)  printf "Invalid option '$1'.\nUse -h for a list of valid options.\n" >&2 ; $exitscript 1 ;;
    esac
    shift
  done

  if [ "$use_default_project" == "y" -a "$k5_project_input" != "" ]; then
    printf "\nThe --defaultproject and --project options cannot be used simultaneously.\n"
    $exitscript 1
  fi

  #
  # Set the aliases used by various API scripts.
  #
  AUTOSCALE='https://autoscale.'$K5_SITE'/autoscale_schedulers'
  CEILOMETER='https://telemetry.'$K5_SITE
  DNS='https://dns.'$K5_CLOUD
  ELB='https://loadbalancing.'$K5_SITE
  IDENTITY=$K5_IDENTITY_URL
  IMAGE='https://image.'$K5_SITE
  MAILSERVICE='https://mail.'$K5_SITE
  NETWORK='https://networking.'$K5_SITE
  NETWORK_EX='https://networking-ex.'$K5_SITE
  TOKEN=$K5_IDENTITY_URL
  TELEMETRY=$CEILOMETER

  #
  # Set the project-dependent URLs.
  #
  setProjectURLs $K5_PROJECT_ID

  #
  # Check the script's pre-requisite commands are available.
  #
  declare prereqsOk=true
  for cmd in curl jq; do
    command -v $cmd >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      printf "This script requires the $cmd command which is not installed.\n"
      prereqsOk=false
    fi
  done

  if [ $prereqsOk = false ]; then
    printf "\nPlease install the missing component\(s\) then try again.\n\nScript aborted.\n\n"
    read -n1 -rsp "Press a key to continue ... "
    popd > /dev/null
    $exitscript 1
  fi
  printf "\n"
  unset prereqsOk

  #
  # Make the curl command use TLS v1.2.
  #
  alias curl='curl --tlsv1.2'

  #
  # Get a contract token.
  #
  getK5Token "$K5_CONTRACT" "" "" "$K5_USERNAME" K5_CONTRACT_TOKEN
  if [ $? -ne 0 ]; then
    popd > /dev/null
    $exitscript $?
  fi

  printf "%s" "$K5_CONTRACT" > .k5lastcontract

  if [ "$K5_USER_ID" == "" ]; then
    printf "\nAuthentication failure. See files .k5contract.header and .k5contract.json for more information.\n"
    popd > /dev/null
    $exitscript 1
  else
    if [ "$verbose_mode" == "y" ]; then
      printf "\n    Contract $K5_CONTRACT has the unique ID $K5_CONTRACT_ID\n"
      printf "    $K5_USERNAME has the unique ID $K5_USER_ID\n"
    fi
  fi

  if [ "$verbose_mode" == "y" ]; then
    printf "\n    Getting the list of projects for your contract ...\n"
  fi

  curl -ks -X GET \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "X-Auth-Token: $K5_CONTRACT_TOKEN" \
    "$K5_USERS_URL/$K5_USER_ID/projects" > .k5projects.json

  K5_PROJECT_COUNT=$(jq -j ".projects|length" .k5projects.json)

  if (( K5_PROJECT_COUNT < 1 )); then
    printf "\nNo projects were found for contract $K5_CONTRACT.\n"
    popd > /dev/null
    $exitscript 1
  fi

  #
  # Use the default project if the --defaultproject option was specified, 
  #
  if [ "$use_default_project" == "y" ]; then
    k5_project_input="$K5_DEFAULT_PROJECT"
  fi
  printf "\n"
  declare i j p projname projid projdesc
  declare -a k5projectnames k5projectids
  p=-1
  for ((i=0; i < K5_PROJECT_COUNT; i++)); do
    projname=$(jq -j ".projects[$i].name" .k5projects.json)
    projid=$(jq -j ".projects[$i].id" .k5projects.json)
    projdesc=$(jq -j ".projects[$i].description" .k5projects.json)
    #
    # If a project name was specified as a script argument, use the matching index instead of prompting.
    #
    if [[ "$projname" == "$k5_project_input" ]]; then
      p=$i
    fi
    k5projectnames[$i]="$projname"
    k5projectids[$i]="$projid"
  done
  printf "\n"
  if (( p < 0 )); then
    getListChoice "Project Name" k5projectnames[@] p
    printf "\n"
  fi
  K5_PROJECT="${k5projectnames[$p]}"
  K5_PROJECT_ID="${k5projectids[$p]}"
  #
  # Refresh the project-dependent URLs.
  #
  setProjectURLs $K5_PROJECT_ID

  unset i j p projname projid projdesc k5projectnames k5projectids

  #
  # Get a project token.
  #
  getK5Token "$K5_CONTRACT" "$K5_PROJECT" "$K5_PROJECT_ID" "$K5_USERNAME" K5_PROJECT_TOKEN
  if [ $? -ne 0 ]; then
    popd > /dev/null
    $exitscript $?
  fi

  printf "%s" "$K5_CONTRACT" > .k5lastcontract
  printf "%s" "$K5_USERNAME" > .k5lastuser
  OS_AUTH_TOKEN=$K5_PROJECT_TOKEN

  #
  # Update the unique ID file.
  #
  updateIdFile "$K5_CONTRACT" "$K5_CONTRACT_ID"
  updateIdFile "$K5_USERNAME" "$K5_USER_ID"
  updateIdFile "$K5_PROJECT" "$K5_PROJECT_ID"

  unset exitscript
  #
  # Clear down work variable values.
  #
  unset -v k5_contract_input k5_password_input k5_project_input k5_username_input use_default_project verbose_mode

  popd > /dev/null    # Go back to original directory

  stty echo    # Turn user keypress echoing back on.
