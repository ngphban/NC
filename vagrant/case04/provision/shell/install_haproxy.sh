#!/usr/bin/env bash

#
# Install HAProxy 
# Script works on Ubuntu/Debian
#
# Script for automatic setup of an HAProxy server on Ubuntu LTS and Debian.
# Works on any dedicated server or Virtual Private Server (VPS) except OpenVZ.
#
# DO NOT RUN THIS SCRIPT ON YOUR PC OR MAC!
#
#
# Copyright (C) 2014-2016 An Nguyen <ngphban@gmail.com>
#
# Usage:
#
# ./install_haproxy.sh [OPTIONS]
#
# OPTIONS:
# -help, -h, -?	Display usage
# -httpport		Specify your port on which your proxy is binded (between 80 and 9999), default is 80
# -version 		Set your installation version of HAProxy, default is latest version
# 

# Set default values for binding port and installation version. 
# Always check the download page of HAProxy to get the latest version.
DEFAULT_BINDING_PORT='80'
DEFAULT_VERSION='1.7.2'

YOUR_BINDING_PORT=''
YOUR_VERSION=''

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Custom exit function
exiterr()  { echo "Error: $1" >&2; exit 1; }

# Define backup/restore functions
SYS_DT="$(date +%Y-%m-%d-%H:%M:%S)"; export SYS_DT
proxy_bk() { /bin/cp -f "$1" "$1.old-$SYS_DT" 2>/dev/null; }
proxy_res() { /bin/cp -f "$1.old-$SYS_DT" "$1" 2>/dev/null; }

# This script only runs on Ubuntu/Debian basing on Upstart
os_type="$(lsb_release -si 2>/dev/null)"
if [ "$os_type" != "Ubuntu" ] && [ "$os_type" != "Debian" ] && [ "$os_type" != "Raspbian" ]; then
 	exiterr "This script only supports Ubuntu/Debian."
fi

# This script does not run on OpenVZ
if [ -f /proc/user_beancounters ]; then
	echo "Error: This script does not support OpenVZ VPS." >&2
  	exit 1
fi

# Print usage
usage() {
cat 1>&2 <<'EOF'
Usage:

./install_haproxy.sh [OPTIONS]

OPTIONS:
-help, -h, -?	Display usage
-httpport		Specify your port on which your proxy is binded (between 80 and 9999), default is 80
-version 		Set your installation version of HAProxy, default is latest version
EOF

exit 1;
}

# Below loop is use to validate script's option
while : 
do
  	case "$1" in 
  	-h | -\? | -help)
		usage
		exit 0
		;;	
  	-httpport)
		YOUR_BINDING_PORT=$2
		if [[ -z $YOUR_BINDING_PORT ]]; then
			exiterr "Options -httpport requires a value"
		fi
		if [[ $YOUR_BINDING_PORT =~ ^[0-9]+$ ]]; then
			if [[ $YOUR_BINDING_PORT -lt 80 || $YOUR_BINDING_PORT -gt 9999 ]]; then
				exiterr "Binding port must be between 80 and 9999!"
			fi	
		else exiterr "Invalid binding port, must be a number!"
		fi
		shift 2
		;;
	-version)
		YOUR_VERSION=$2
		if [[ -z $YOUR_VERSION ]]; then
			exiterr "Options -version require a non-empty value!"
		fi
		if ! [[ $YOUR_VERSION =~ ^[0-9.]+$ ]]; then
			exiterr "Invalid version!"
		fi
		shift 2
		;;
	-*)
		exiterr "Unknown option $1!" 
		;;
	*)	
		break
		;;
	esac
done

# Set binding port and installation version to default if they are not set in script's option
if [[ -z $YOUR_BINDING_PORT ]]; then
	YOUR_BINDING_PORT=$DEFAULT_BINDING_PORT
fi

if [[ -z $YOUR_VERSION ]]; then
	YOUR_VERSION=$DEFAULT_VERSION
fi

# Script requires sudo priviledge escalation
if [ "$(id -u)" != 0 ]; then
	exiterr "Script must be run as root. Try 'sudo sh $0'"
fi

# Backup if there is already one HAProxy instance running
IS_RUNNING=$(ps ax | grep -v grep | grep haproxy -q; echo $?)
if [ "$IS_RUNNING" == 0 ]; then
	echo "HAProxy is running. Backing up now..."
	proxy_bk "/etc/haproxy/haproxy.cfg"
	proxy_bk "/usr/sbin/haproxy"
	echo "Stopping HAProxy"
	service haproxy stop
fi

# Check if there is any other application running on the supplied port
IS_BINDING=$(netstat -ntpl | grep [0-9]:${1:-"$YOUR_BINDING_PORT"} -q; echo $?)
if [ "$IS_BINDING" == 0 ]; then
	exiterr "Your supplied port is already running. Consider using another port."
#else echo "Port is not running"
fi	

export HAPROXY_VERSION=$YOUR_VERSION
export HAPROXY_CPU=generic

# Define the function that installs HAProxy from source
function install_haproxy {

# Update package index
export DEBIAN_FRONTEND=noninteractive
apt-get -yq update || exiterr "'apt-get update' failed."

# Download the compilers and prerequisite -dev packages
export DEBIAN_FRONTEND=noninteractive
apt-get -q -y install build-essential libssl-dev libpcre3-dev zlib1g-dev virt-what || exiterr "'apt-get install' failed."

# If we are running on bare metal and not in a virtual environment, the compile with 
# CPU-native features.
export IS_VIRTUALIZED=`virt-what` 
if [ "${IS_VIRTUALIZED}" = "" ]; then
	export HAPROXY_CPU=native
fi


# Create and change to working dir
mkdir -p /usr/src
cd /usr/src || exiterr "Cannot enter /usr/src."

# Download the source code
SOURCE_FILE="haproxy-$HAPROXY_VERSION.tar.gz"
SOURCE_BRANCH=$(echo $HAPROXY_VERSION | awk -F "." '{print $1 "." $2}')
URL="http://www.haproxy.org/download/$SOURCE_BRANCH/src/$SOURCE_FILE"

if ! { wget -t 3 -T 30 -nv -O "$SOURCE_FILE" "$URL" 2>/tmp/output.log; }; then
	if { grep -qs 'Not Found' /tmp/output.log; }; then
		exiterr "Source version not found!"
	else exiterr "Cannot download HAProxy source. See ERROR above!"
	fi
fi

tar xzf "$SOURCE_FILE" && /bin/rm -f "$SOURCE_FILE"
cd "haproxy-$HAPROXY_VERSION" || exiterr "Cannot enter HAProxy source dir!"

# Compile and install
make TARGET=linux2628 CPU=${HAPROXY_CPU} USE_PCRE=1 USE_OPENSSL=1 USE_ZLIB=1 && make install PREFIX=/usr

# Restore to previous version if new installation failed
if ! { /usr/sbin/haproxy -version 2>/dev/null | grep -o "$HAPROXY_VERSION"; }; then
  echo "HAProxy $HAPROXY_VERSION failed to build."
  echo "Rolling back to backed-up version"
  proxy_res "/usr/sbin/haproxy"
  proxy_res "/etc/haproxy/haproxy.cfg"
  service haproxy start
  exit 0
fi

# Test for haproxy user and create it if needed. Chroot it and prevent it from 
# getting shell access
id -u haproxy &>/dev/null || useradd -d /var/lib/haproxy -s /bin/false haproxy

# Set up the default haproxy config files
mkdir -p /etc/haproxy/errors
cp ./examples/errorfiles/* /etc/haproxy/errors
cat > /etc/haproxy/haproxy.cfg <<EOF
global
  log /dev/log  local0
  log /dev/log  local1 notice
  chroot /var/lib/haproxy
  stats socket /run/haproxy/admin.sock mode 660 level admin
  stats timeout 30s
  user haproxy
  group haproxy
  daemon

  # Default SSL material locations
  ca-base /etc/ssl/certs
  crt-base /etc/ssl/private

  # Default ciphers to use on SSL-enabled listening sockets.
  # For more information, see ciphers(1SSL).
  ssl-default-bind-ciphers kEECDH+aRSA+AES:kRSA+AES:+AES256:RC4-SHA:!kEDH:!LOW:!EXP:!MD5:!aNULL:!eNULL

defaults
  log global
  mode  http
  option  httplog
  option  dontlognull
        timeout connect 5000
        timeout client  50000
        timeout server  50000
  errorfile 400 /etc/haproxy/errors/400.http
  errorfile 403 /etc/haproxy/errors/403.http
  errorfile 408 /etc/haproxy/errors/408.http
  errorfile 500 /etc/haproxy/errors/500.http
  errorfile 502 /etc/haproxy/errors/502.http
  errorfile 503 /etc/haproxy/errors/503.http
  errorfile 504 /etc/haproxy/errors/504.http

frontend http_front
   bind *:$YOUR_BINDING_PORT
   stats uri /haproxy?stats
   default_backend http_back

backend http_back
   balance roundrobin
   server webserver_01 192.168.30.10:8080 check
   server webserver_02 192.168.30.20:8080 check
EOF

# Add the /etc/default script
cat > /etc/default/haproxy <<EOF
# Defaults file for HAProxy
#
# This is sourced by both, the initscript and the systemd unit file, so do not
# treat it as a shell script fragment.

ENABLED=1

# Change the config file location if needed
#CONFIG="/etc/haproxy/haproxy.cfg"

# Add extra flags here, see haproxy(1) for a few options
#EXTRAOPTS="-de -m 16"
EOF

# Add the default init.d script
 cat > /etc/init.d/haproxy <<EOF
#!/bin/sh
### BEGIN INIT INFO
# Provides:          haproxy
# Required-Start:    \$local_fs \$network \$remote_fs \$syslog
# Required-Stop:     \$local_fs \$remote_fs \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: fast and reliable load balancing reverse proxy
# Description:       This file should be used to start and stop haproxy.
### END INIT INFO

# Author: Arnaud Cornet <acornet@debian.org>

PATH=/sbin:/usr/sbin:/bin:/usr/bin
PIDFILE=/var/run/haproxy.pid
CONFIG=/etc/haproxy/haproxy.cfg
HAPROXY=/usr/sbin/haproxy
RUNDIR=/run/haproxy
EXTRAOPTS=

test -x \$HAPROXY || exit 0

if [ -e /etc/default/haproxy ]; then
	. /etc/default/haproxy
fi

test -f "\$CONFIG" || exit 0

[ -f /etc/default/rcS ] && . /etc/default/rcS
. /lib/lsb/init-functions


check_haproxy_config()
{
	\$HAPROXY -c -f "\$CONFIG" >/dev/null
	if [ \$? -eq 1 ]; then
		log_end_msg 1
		exit 1
	fi
}

haproxy_start()
{
	[ -d "\$RUNDIR" ] || mkdir "\$RUNDIR"
	chown haproxy:haproxy "\$RUNDIR"
	chmod 2775 "\$RUNDIR"

	check_haproxy_config

	start-stop-daemon --quiet --oknodo --start --pidfile "\$PIDFILE" \\
		--exec \$HAPROXY -- -f "\$CONFIG" -D -p "\$PIDFILE" \\
		\$EXTRAOPTS || return 2
	return 0
}

haproxy_stop()
{
	if [ ! -f \$PIDFILE ] ; then
		# This is a success according to LSB
		return 0
	fi
	for pid in \$(cat \$PIDFILE) ; do
		/bin/kill \$pid || return 4
	done
	rm -f \$PIDFILE
	return 0
}

haproxy_reload()
{
	check_haproxy_config

	\$HAPROXY -f "\$CONFIG" -p \$PIDFILE -D \$EXTRAOPTS -sf \$(cat \$PIDFILE) \\
		|| return 2
	return 0
}

haproxy_status()
{
	if [ ! -f \$PIDFILE ] ; then
		# program not running
		return 3
	fi

	for pid in \$(cat \$PIDFILE) ; do
		if ! ps --no-headers p "\$pid" | grep haproxy > /dev/null ; then
			# program running, bogus pidfile
			return 1
		fi
	done

	return 0
}


case "\$1" in
start)
	log_daemon_msg "Starting haproxy" "haproxy"
	haproxy_start
	ret=\$?
	case "\$ret" in
	0)
		log_end_msg 0
		;;
	1)
		log_end_msg 1
		echo "pid file '\$PIDFILE' found, haproxy not started."
		;;
	2)
		log_end_msg 1
		;;
	esac
	exit \$ret
	;;
stop)
	log_daemon_msg "Stopping haproxy" "haproxy"
	haproxy_stop
	ret=\$?
	case "\$ret" in
	0|1)
		log_end_msg 0
		;;
	2)
		log_end_msg 1
		;;
	esac
	exit \$ret
	;;
reload|force-reload)
	log_daemon_msg "Reloading haproxy" "haproxy"
	haproxy_reload
	ret=\$?
	case "\$ret" in
	0|1)
		log_end_msg 0
		;;
	2)
		log_end_msg 1
		;;
	esac
	exit \$ret
	;;
restart)
	log_daemon_msg "Restarting haproxy" "haproxy"
	haproxy_stop
	haproxy_start
	ret=\$?
	case "\$ret" in
	0)
		log_end_msg 0
		;;
	1)
		log_end_msg 1
		;;
	2)
		log_end_msg 1
		;;
	esac
	exit \$ret
	;;
status)
	haproxy_status
	ret=\$?
	case "\$ret" in
	0)
		echo "haproxy is running."
		;;
	1)
		echo "haproxy dead, but \$PIDFILE exists."
		;;
	*)
		echo "haproxy not running."
		;;
	esac
	exit \$ret
	;;
*)
	echo "Usage: /etc/init.d/haproxy {start|stop|reload|restart|status}"
	exit 2
	;;
esac

EOF
chmod +x /etc/init.d/haproxy

# Make a chroot for haproxy, add syslog config to make log socket in said chroot
mkdir -p /var/lib/haproxy/dev

cat > /etc/rsyslog.d/haproxy.conf <<EOF
# Create an additional socket in haproxy's chroot in order to allow logging via
# /dev/log to chroot'ed HAProxy processes
\$AddUnixListenSocket /var/lib/haproxy/dev/log

# Send HAProxy messages to a dedicated logfile
if \$programname startswith 'haproxy' then /var/log/haproxy.log
&~
EOF

# And rotate the logs so it doesn't overfill
cat > /etc/logrotate.d/haproxy <<EOF
/var/log/haproxy.log {
    daily
    rotate 52
    missingok
    notifempty
    compress
    delaycompress
    postrotate
        invoke-rc.d rsyslog rotate >/dev/null 2>&1 || true
    endscript
}
EOF

# Start on reboot
update-rc.d haproxy defaults
service haproxy restart

# Clean up
cd /usr/src || exiterr "Cannot enter /usr/src."
/bin/rm -rf "/usr/src/haproxy-$HAPROXY_VERSION"

cat <<EOF

================================================

HAProxy server is now ready for use!

================================================

EOF
echo "Installed HAProxy version: $HAPROXY_VERSION"
exit 0
}



# Actually execute the installations
cat <<'EOF'
Installation is ready, press Ctrl-C to interrupt now.

Continuing in 10 seconds ...

EOF
  sleep 10

echo "HAProxy setup in progress... Please be patient."
echo
  install_haproxy

exit 0