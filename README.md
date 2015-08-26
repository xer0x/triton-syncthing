triton-syncthing
================

[Syncthing](http://syncthing.net/) Docker image with automatic clustering for Joyent's Triton

[Syncthing](http://syncthing.net/) provides a syncing mechanism similar to
[Dropbox][1] or [BT-Sync][2]. By default files in the /home/syncthing/Sync
folder will be copied between each container. The triton-syncthing containers
use Consul to discover the IP address of another Syncthing container on the


### How to run


#### Run a Syncthing device

  docker run -d \
    --restart always \
    -p 8384 -p 22000 -p 21025/udp \
    --link ${consul_name}:consul1 \
    xer0x/triton-syncthing username password

Then access Syncthing Web UI at [http://localhost:8384/]()


#### Run a Consul container

  consul_name=consul1

  docker run -d \
    --name $consul_name \
    -p 8400 -p 8500 -p 53/udp \
    --restart=always \
    -h $consul_name progrium/consul -server -bootstrap -ui-dir /ui

  CONSUL_IP="$(docker inspect -f '{{.NetworkSettings.IPAddress}}' $consul_name)"

  echo "http://${CONSUL_IP}:8500/ui"


[1]: www.dropbox.com Dropbox
[2]: www.getsync.com Bittorrent Sync
