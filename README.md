triton-syncthing
================

[Syncthing](http://syncthing.net/) Docker image with automatic clustering for Joyent's Triton

### How to run

	docker run -d \
	  --name syncthing \
	  --restart always \
          -p 8384 -p 22000 -p 21025/udp \
          xer0x/triton-syncthing
        
Then access Syncthing Web UI at [http://localhost:8384/]()


Thanks to istepanov this image is based on istepanov/docker-syncthing
