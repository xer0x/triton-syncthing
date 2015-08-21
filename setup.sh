#!/usr/bin/env bash

#set -x

if [ "$2" == "" ]; then
  echo Error: $0 expects user and password
  echo
  echo "Usage: $0 user password"
  exit
fi

username=$1
password=$2

function wait-for-syncthing {
  #echo -n 'Waiting..'
  local hostname=$1
  echo "Waiting for API be up..."
  local ST_RESPONSIVE=0
  while [ $ST_RESPONSIVE != 1 ]; do
    #echo -n '.'
    curl -s "http://${hostname}:8384" > /dev/null 2>&1
    if [ $? == 0 ]; then
      let ST_RESPONSIVE=1
    else
      sleep 1.3
    fi
  done
  echo "API ready."
}

function abort-if-setup {
  if [ -e /setup.finished ]; then
    echo Setup aborting. Already completed.
    exit
  fi
}

function configure {
  wait-for-syncthing localhost

  export STUSERNAME=$username
  export STPASSWORD=$password

  syncthing-cli gui set user "$username"
  syncthing-cli gui set password "$password"
  syncthing-cli gui set address "0.0.0.0:8384"

  # if started with `docker --link introducer:container_name`
  ping -c1 -q introducer > /dev/null 2>&1
  if [ $? == 0 ]; then
    wait-for-syncthing introducer
    INTRODUCER_ID=$(syncthing-cli --endpoint 'http://introducer:8384' id)
    MY_ID=$(syncthing-cli id)
    syncthing-cli devices add $INTRODUCER_ID
    syncthing-cli --endpoint 'http://introducer:8384' devices add $MY_ID
    syncthing-cli folders devices add default $INTRODUCER_ID
    syncthing-cli --endpoint 'http://introducer:8384' folders devices add default $MY_ID
    syncthing-cli --endpoint 'http://introducer:8384' status
    #syncthing-cli --endpoint 'http://introducer:8384' restart
  else
    echo "Introducer network link was not sent."
  fi
  echo done

  echo Added $MY_ID to Syncthing cluster
  touch /setup.finished

  syncthing-cli status
}

function main {
  abort-if-setup
  configure
}

main

