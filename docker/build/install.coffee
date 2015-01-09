require 'shelljs/global'

# Link node
ln '-s', '/usr/bin/nodejs', '/usr/bin/node'

# Disable ssh
rm '-rf', '/etc/service/sshd /etc/my_init.d/00_regen_ssh_host_keys.sh'

# Install consul
cp 'consul', '/usr/local/bin/consul'
mkdir '/etc/service/consul'
cp 'consul.sh', '/etc/service/consul/run'
mkdir '/etc/service/consul/control'
cp 'consul-down.sh', '/etc/service/consul/control/t'
'2'.to '/etc/container_environment/GOMAXPROCS'
mkdir '/consul-data'

# Install Consul Doppelganger
exec 'npm install -g consul-doppelganger'
mkdir '/etc/service/doppelganger'
cp 'doppelganger.sh', '/etc/service/doppelganger/run'

# Install Redwire Harmony
exec 'npm install -g redwire-harmony'
mkdir '/etc/service/harmony'
cp 'harmony.sh', '/etc/service/harmony/run'

# Volumes to read configuration data from.
# They can all be mounted as the same volume if desired
# as consul requires .json, doppelganger requires .yml
# and harmony requires .js
# This makes it nice and easy to configure.
mkdir '/consul'
mkdir '/doppelganger'
mkdir '/harmony'
