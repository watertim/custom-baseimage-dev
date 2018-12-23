#!/bin/bash

# Enable SSH
rm -f /etc/service/sshd/down
/etc/my_init.d/00_regen_ssh_host_keys.sh
touch /etc/service/sshd/down

# Setup SSH key
if [ "x$SSH_AUTHORIZED_KEYS" = "x" ]; then
	/usr/sbin/enable_insecure_key
else
	mkdir ~/.ssh
	echo "$SSH_AUTHORIZED_KEYS" | sed 's/\\n/\n/g' > ~/.ssh/authorized_keys
	chmod 400 ~/.ssh/authorized_keys
fi

# Start web server
env | grep -E '^MARATHON_HOST=|MARATHON_PORT_' > /home/wwwroot/default/marathon.conf
if [ "x$MARATHON_HOST" != "x" ]; then
	getent hosts $MARATHON_HOST | awk '{print "MARATHON_HOST_IP="$1; exit;}' >> /home/wwwroot/default/marathon.conf
fi

start-stop-daemon -S -b -n tmp-httpd -d /home/wwwroot/default -x /usr/bin/python3 -- -m http.server 80

# Start ShadowSocks
env | grep '^SHADOWSOCKS_CFGS_' | awk -F '=' '{print $1;}' | while read T_NAME; do
	SS_NAME="${T_NAME:17}"
	echo "${!T_NAME}" > /etc/shadowsocks-libev/${SS_NAME}.json
	start-stop-daemon -n ss-$SS_NAME -x /usr/bin/ss-server -b -S -- -c /etc/shadowsocks-libev/${SS_NAME}.json -u --fast-open
done

if [ "x$GETT_TOKEN" != "x" ]; then
	if [ "x$HOME" = "x" ]; then
		export HOME="/root"
	fi
	echo -n "$GETT_TOKEN" > ~/.gett-token
	if [ "x$GETT_SHARE_NAME" != "x" ]; then
		python3 /usr/local/gett/uploader.py -l http://ge.tt/$GETT_SHARE_NAME | awk '{if (substr($5,1,13)=="http://ge.tt/") {print $5;}}' | xargs python3 /usr/local/gett/uploader.py --delete
		python3 /usr/local/gett/uploader.py -s http://ge.tt/$GETT_SHARE_NAME /home/wwwroot/default/marathon.conf
	fi
fi

#Test for installing dev-tool
sh -c 'apt-get update'
sh -c 'apt-get install build-essential wget sudo nano -y'

#Brook server installation
sh -c 'curl -L https://github.com/txthinking/brook/releases/download/v20181212/brook >> /root/brook'
sh -c 'cd /root && chmod +x brook && nohup ./brook server --tcpDeadline 60 --udpDeadline 0 -l :9999 -p 12345678 &'

#aria2 installation
#sh -c 'apt-get install aria2 -y'
#sh -c 'cd /lib/x86_64-linux-gnu && rm -rf libsodium.so.18 libpcre.so.0 libmbedcrypto.so.0 libev.so.4'
#sh -c 'cd /lib/x86_64-linux-gnu && ln libsodium.so.18.1.1 libsodium.so.18 && ln libpcre.so.3.13.3 libpcre.so.0 && ln libmbedcrypto.so.2.4.0 libmbedcrypto.so.0 && ln libev.so.4.0.0 libev.so.4'
#sh -c 'apt-get install aria2 -y'
#sh -c 'mkdir /etc/aria2'
#sh -c 'curl -L https://github.com/watertim/custom-baseimage-dev/raw/master/aria2.conf >> /etc/aria2/aria2.conf'
#sh -c 'touch /etc/aria2/aria2.session'
#chmod 777 /etc/aria2/aria2.session
#sh -c 'mkdir /home/wwwroot/default/download'
#chmod 777 /home/wwwroot/default/download
#sh -c 'aria2c --conf-path=/etc/aria2/aria2.conf --enable-rpc --rpc-listen-all --rpc-allow-origin-all -c  --dir /home/wwwroot/default/download -D'

#softether server installation
sh -c 'curl -L https://github.com/SoftEtherVPN/SoftEtherVPN_Stable/releases/download/v4.28-9669-beta/softether-vpnserver-v4.28-9669-beta-2018.09.11-linux-x64-64bit.tar.gz >> /softether-vpnserver.tar.gz'
sh -c 'tar -xvf /softether-vpnserver.tar.gz -C /root/'

exec /usr/sbin/sshd -D -e -u 0
