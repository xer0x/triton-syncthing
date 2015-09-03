#!/usr/bin/env bash

# TODO: do we need to export STUSERNAME and STPASSWORD ?

# TODO deregister containers from Consul when they are destroyed

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

  # TODO: Wait for consul to be available ?

  INTRODUCER_IP=$(curl --retry 4 --retry-delay 2 -L -s -f http://$consul:8500/v1/catalog/service/syncthing | json -aH ServiceAddress | head -1)
  if [ -n "$INTRODUCER_IP" ]; then
    getAuthKeys
  else
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
    echo '# TODO: kill setup.sh pid'
    exit
  else
    echo '# Consul instance found and responsive'
    echo '#'
  fi
}

function wait_for_syncthing {
  #echo -n 'Waiting..'
  local hostname=$1
  echo "Waiting for API be up on ${hostname}..."
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

function abort_if_setup {
  if [ -e /setup.finished ]; then
    echo Setup aborting. Already completed.
    exit
  fi
}

function configure {
  wait_for_syncthing localhost

  syncthing-cli gui set user "$STUSERNAME"
  syncthing-cli gui set password "$STPASSWORD"
  syncthing-cli gui set address "0.0.0.0:8384"
  syncthing-cli devices set $MY_ID introducer true
  # TODO set syncthing name to docker_container name (not the current hash id?)
  MY_ID=$(syncthing-cli id)

  if [ -n "$INTRODUCER_IP" ]; then
    # WARNING: not everything responds to ping
    #ping -c1 -q $INTRODUCER_IP > /dev/null 2>&1
    #if [ $? == 0 ]; then
    if [ 1 == 1 ]; then
      wait_for_syncthing $INTRODUCER_IP
      echo "#"
      echo "# Introducing new device to Syncthing cluster"
      echo "#"
      INTRODUCER_ID=$(syncthing-cli --endpoint "http://${INTRODUCER_IP}:8384" id)
      syncthing-cli devices add $INTRODUCER_ID
      syncthing-cli --endpoint "http://$INTRODUCER_IP:8384" devices add $MY_ID
      syncthing-cli devices set $INTRODUCER_ID introducer true
      syncthing-cli folders devices add default $INTRODUCER_ID
      syncthing-cli --endpoint "http://$INTRODUCER_IP:8384" folders devices add default $MY_ID
      echo "# Introducer status"
      syncthing-cli --endpoint "http://$INTRODUCER_IP:8384" status
      echo "# Restarting Introducer"
      syncthing-cli --endpoint "http://$INTRODUCER_IP:8384" restart
    else
      echo "Introducer IP ${INTRODUCER_IP} is not reachable."
      echo "TODO: deregister this missing introducer"
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

