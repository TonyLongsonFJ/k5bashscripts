#!/bin/bash
  . ./k5token.sh "$@"
  if [ "$OS_AUTH_TOKEN" = "" ]; then exit 1; fi
  curl -X GET -k -s $NETWORK/v2.0/ports -H "X-Auth-Token: $OS_AUTH_TOKEN" | jq .
