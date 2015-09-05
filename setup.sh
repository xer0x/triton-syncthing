#!/usr/bin/env bash

#
# Setup Syncthing to connect to a mesh of devices.
#
# Overview:
#
# We use Consul to store both the list of devices, and a shared username and password for all the devices.
#
# If this is the first Syncthing device to talk to Consul, then we choose a random authentication values. We register ourselves with Consul as a running service.
#
# Otherwise, we use the authentication values in Consul. Next we ask Consul for the IP address of another running Syncthing device. We connect to this Syncthing with "Introducer mode" enabled.
#
# "Introducer mode" is the special magic that will keep our mesh network of containers linked together. When "Introducer mode" is enabled the device will tell us about all the other devices that it knows about. It will also tell us about any new devices that it learns about.
#
# I feel that Syncthing's UI and easy clustering with "Introducer mode" give it the edge over other tools that we could have used like Rsync, Unison, or Bittorrent-Sync.
#
# We use syncthing-cli to update each device's configuration.
#


# TODO healthcheck and deregister containers from Consul when they are destroyed


#set -o xtrace

consul=consul

function setAuthKeys {
  export STUSERNAME=$(echo $(printf '%s %s %s' $(date +%s%N) $(hostname) salt) | sha256sum | head -c 64)
  curl --retry 7 --retry-delay 3 -X PUT -d $STUSERNAME http://$consul:8500/v1/kv/syncthing/username

  export STPASSWORD=$(echo $(printf '%s %s %s' $(date +%s%N) $(hostname) salt) | sha256sum | head -c 64)
  curl --retry 7 --retry-delay 3 -X PUT -d $STPASSWORD http://$consul:8500/v1/kv/syncthing/password
}

function getAuthKeys {
  export STUSERNAME=$(curl --retry 6 --retry-delay 3 -L -s -f http://$consul:8500/v1/kv/syncthing/username | json -aH Value | base64 --decode)
  export STPASSWORD=$(curl --retry 6 --retry-delay 3 -L -s -f http://$consul:8500/v1/kv/syncthing/password | json -aH Value | base64 --decode)
}

function getConfiguration {
  echo
  echo '#'
  echo '# Checking Consul for configuration'
  echo '#'

  INTRODUCER_IP=$(curl --retry 6 --retry-delay 2 -L -s -f http://$consul:8500/v1/catalog/service/syncthing | json -aH ServiceAddress | head -1)
  if [ -n "$INTRODUCER_IP" ]; then
    echo '# Using existing authentication keys from Consul'
    getAuthKeys
  else
    echo '# Adding new authentication keys to Consul'
    setAuthKeys
  fi
}

function register_service_with_consul {

  export MYIPPRIVATE=$(ip addr show eth0 | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
  #export MYIPPUBLIC=$(ip addr show eth1 | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')

  echo
  echo '#'
  echo '# Registering service instance'
  echo '#'

  curl -f -s --retry 7 --retry-delay 3 http://$consul:8500/v1/agent/service/register -d "$(printf '{"ID":"%s","Name":"syncthing","Address":"%s"}' $MY_ID $MYIPPRIVATE)"
  if [ $? == 0 ]; then
    echo "# Added ${MY_ID} to Syncthing cluster"
    touch /setup.finished
  else
    echo '# Error: unable to register container with Consul'
    echo '#'
    echo 'Will retry on next container restart.'
    exit 1
  fi
}

function wait_for_consul {
  echo
  echo '#'
  echo '# Checking Consul availability'
  echo '#'

  curl -fs --retry 7 --retry-delay 3 http://$consul:8500/v1/agent/services &> /dev/null
  if [ $? -ne 0 ]
  then
    echo '#'
    echo '# Consul is required, but unreachable'
    echo '#'
    curl http://$consul:8500/v1/agent/services
    echo
    echo '#'
    echo '# Aborting setup and exiting Container because Consul is unreachable'
    echo '#'
    kill $PPID
    exit 1
  else
    echo '# Consul instance found and responsive'
    echo '#'
  fi
}

function wait_for_syncthing {
  #echo -n 'Waiting..'
  local hostname=$1
  echo "# Waiting for API be up on ${hostname}..."
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
  echo "# API ready."
}

function abort_if_setup {
  if [ -e /setup.finished ]; then
    echo '# Setup aborting. Already completed.'
    exit
  fi
}

function configure {
  wait_for_syncthing localhost

  syncthing-cli gui set user "$STUSERNAME"
  syncthing-cli gui set password "$STPASSWORD"
  syncthing-cli gui set address "0.0.0.0:8384"
  # TODO set syncthing name to docker_container name

  MY_ID=$(syncthing-cli id)
  syncthing-cli devices set $MY_ID introducer true

  if [ -n "$INTRODUCER_IP" ]; then
    ping -c1 -q $INTRODUCER_IP > /dev/null 2>&1
    if [ $? == 0 ]; then
      wait_for_syncthing $INTRODUCER_IP
      echo "#"
      echo "# Adding new device to Syncthing cluster using Syncthing:${INTRODUCER_ID} as an Introducer device"
      echo "#"
      # Syncthing-cli uses the env vars STUSERNAME/STPASSWORD to authenticate
      INTRODUCER_ID=$(syncthing-cli --endpoint "http://${INTRODUCER_IP}:8384" id)
      syncthing-cli devices add $INTRODUCER_ID
      syncthing-cli --endpoint "http://$INTRODUCER_IP:8384" devices add $MY_ID
      syncthing-cli devices set $INTRODUCER_ID introducer true
      echo "# Enabling sync for 'default' folder"
      syncthing-cli folders devices add default $INTRODUCER_ID
      syncthing-cli --endpoint "http://$INTRODUCER_IP:8384" folders devices add default $MY_ID
      echo "# Introducer status"
      syncthing-cli --endpoint "http://$INTRODUCER_IP:8384" status
      echo "# Restarting Introducer"
      syncthing-cli --endpoint "http://$INTRODUCER_IP:8384" restart
    else
      echo "Introducer IP ${INTRODUCER_IP} is not reachable."
      exit 1
    fi
  else
    echo "#"
    echo "# Bootstrapping Syncthing cluser with first device"
    echo "#"
  fi
  register_service_with_consul

  echo "# Syncthing status"
  syncthing-cli status
  echo "# Restarting Syncthing"
  syncthing-cli restart
}

function main {
  abort_if_setup
  wait_for_consul
  getConfiguration
  configure
}

main

