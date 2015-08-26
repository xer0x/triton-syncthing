FROM golang
MAINTAINER Drew Miller <drew@joyent.com>

ENV VERSION v0.11.20

ENV DEBIAN_FRONTEND noninteractive

#RUN apt-get update && \
#    apt-get install -y git xmlstarlet && \
#    rm -rf /var/lib/apt/lists/*

RUN useradd -m syncthing

RUN mkdir -p /go/src/github.com/syncthing && \
    cd /go/src/github.com/syncthing && \
    git clone https://github.com/syncthing/syncthing.git && \
    cd syncthing && \
    git checkout $VERSION && \
    go run build.go && \
    mv bin/syncthing /home/syncthing/syncthing && \
    chown syncthing:syncthing /home/syncthing/syncthing && \
    rm -rf /go/src/github.com/syncthing

RUN go get github.com/syncthing/syncthing-cli

# installed Node.js, similar to https://github.com/joyent/docker-node/blob/428d5e69763aad1f2d8f17c883112850535e8290/0.12/Dockerfile
RUN gpg --keyserver pool.sks-keyservers.net --recv-keys 7937DFD2AB06298B2293C3187D33FF9D0246406D 114F43EE0176B71C7BC219DD50A3051F888C628D

ENV NODE_VERSION 0.12.4
ENV NPM_VERSION 2.10.1

RUN curl -SLO "http://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.gz" \
  && curl -SLO "http://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --verify SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-x64.tar.gz\$" SHASUMS256.txt.asc | sha256sum -c - \
  && tar -xzf "node-v$NODE_VERSION-linux-x64.tar.gz" -C /usr/local --strip-components=1 \
  && rm "node-v$NODE_VERSION-linux-x64.tar.gz" SHASUMS256.txt.asc \
  && npm install -g npm@"$NPM_VERSION" \
  && npm cache clear

RUN npm install -g json

ADD consul_env.sh /consul_env.sh
RUN chmod +x /consul_env.sh

ADD start.sh /start.sh
RUN chmod +x /start.sh

ADD setup.sh /setup.sh
RUN chmod +x /setup.sh

WORKDIR /home/syncthing

VOLUME ["/home/syncthing/.config/syncthing", "/home/syncthing/Sync"]

EXPOSE 8384 22000 21025/udp

CMD ["/start.sh"]

