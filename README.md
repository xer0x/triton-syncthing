triton-syncthing
================

[Syncthing](http://syncthing.net/) Docker image with automatic clustering for Joyent's Triton

### How to run


#### Run introducer server device

  docker run -d \
    --name syncthing \
    --restart always \
    -p 8384 -p 22000 -p 21025/udp \
    xer0x/triton-syncthing username password

#### Run a client that will connect to the first server

  docker run -d \
    --name syncthing \
    --restart always \
    -p 8384 -p 22000 -p 21025/udp \
    --link syncthing1:introducer \
    xer0x/triton-syncthing username password

Then access Syncthing Web UI at [http://localhost:8384/]()


Thanks to istepanov for creating istepanov/docker-syncthing.
