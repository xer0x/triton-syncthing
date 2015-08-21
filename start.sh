#!/bin/bash

set -e

HOME=`eval echo ~syncthing`
CONFIG_FOLDER="$HOME/.config/syncthing"
CONFIG_FILE="$CONFIG_FOLDER/config.xml"

if [ ! -f "$CONFIG_FILE" ]; then
    $HOME/syncthing -generate="$CONFIG_FOLDER"
fi

chown -R syncthing:syncthing "$HOME"

/setup.sh "$@" &

su - syncthing -c $HOME/syncthing
