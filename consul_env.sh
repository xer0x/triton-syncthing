# "Use this to configure your shell for syncthing-cli and to get the web url:"
# "  source /consul_env.sh"

consul=consul
export STUSERNAME=$(curl -L -s -f http://$consul:8500/v1/kv/syncthing/username | json -aH Value | base64 --decode)
export STPASSWORD=$(curl -L -s -f http://$consul:8500/v1/kv/syncthing/password | json -aH Value | base64 --decode)
export MYIPPUBLIC=$(ip addr show eth1 | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
export WEB_URL="http://$STUSERNAME:$STPASSWORD@$MYIPPUBLIC:8384"
