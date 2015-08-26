consul=consul
export STUSERNAME=$(curl -L -s -f http://$consul:8500/v1/kv/syncthing/username | json -aH Value | base64 --decode)
export STPASSWORD=$(curl -L -s -f http://$consul:8500/v1/kv/syncthing/password | json -aH Value | base64 --decode)
