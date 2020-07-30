#!/usr/bin/env bash

PORT=443
IF='ens2'
DOMAIN='example.net'
WIREGUARD_NET='10.192'
WIREGUARD_NETMASK='16'
WIREGUARD_IP='10.192.1.1'
UPSTREAM_DNS_RESOLVER='1.1.1.1'
WIREGUARD_DNS_IP="$WIREGUARD_IP"
WIREGUARD_CONFIG='/etc/wireguard/wg0.conf'

log() {

  local fn="`basename "$1"`"
  shift 1

  mkdir -p logs &&
  touch "logs/$fn.log" &&
  echo -n "Running '$fn'... " &&
  $fn &> "logs/$fn.log"
  rv="$?"

  if [ "$rv" -eq 0 ]; then
    echo 'done.'
  else
    echo 'failed.'
  fi

  return "$rv"
}

update_apt() {

  export DEBIAN_FRONTEND=noninteractive &&
  apt-get -q update &&
  apt-get -q -y autoremove
}

install_apt() {

  export DEBIAN_FRONTEND=noninteractive &&
  \
  apt-get -q update &&
  apt-get -q -y -o Dpkg::Options::="--force-confnew" dist-upgrade &&
  apt-get -q -y -o Dpkg::Options::="--force-confnew" install \
    wireguard wireguard-dkms zlib1g-dev uuid-dev libblkid-dev nodejs \
    daemontools-run ucspi-tcp exiftool jq curl qrencode iputils-ping &&
  \
  apt-get -q -y autoremove &&
  echo 'wireguard' > /lib/modules-load.d/wireguard.conf &&
  echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf &&
  touch "$WIREGUARD_CONFIG" &&
  chmod 0600 "$WIREGUARD_CONFIG" &&
  systemctl enable wg-quick@wg0
}

install_djbdns() {

  curl -LO# 'https://cr.yp.to/djbdns/djbdns-1.05.tar.gz' &&
  tar xvzf 'djbdns-1.05.tar.gz' &&
  (cd 'djbdns-1.05' &&
   echo gcc -O2 -include /usr/include/errno.h > conf-cc &&
   make && make setup check &&
   for u in dnscache tinydns; do
     groupadd -f "$u" &&
     id -u "$u" &>/dev/null \
       || useradd -d /var/empty -g "$u" -MNrs /bin/true "$u" || return 1
   done)
}

deploy_dnscache() {

  dnscache-conf dnscache dnscache /etc/dnscache &&
  echo "$UPSTREAM_DNS_RESOLVER" > /etc/dnscache/root/servers/@ &&
  echo "$WIREGUARD_DNS_IP" > /etc/dnscache/env/IP &&
  echo 1 > /etc/dnscache/env/FORWARDONLY &&
  touch "/etc/dnscache/root/ip/$WIREGUARD_NET" &&
  ln -s /etc/dnscache /etc/service/dnscache
}

install_all () {

  log update_apt &&
  log install_apt &&
  log install_djbdns &&
  log deploy_dnscache &&
  \
  echo -n 'Success; rebooting in 60 seconds... ' &&
  sync && sleep 60 && sync &&
  echo 'rebooting.' &&
  \
  reboot
}

