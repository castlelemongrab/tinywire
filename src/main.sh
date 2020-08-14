#!/usr/bin/env bash

source config/tinyguard.conf

log() {

  local fn="`basename "$1"`"
  shift 1

  local rv='1'

  which pv &>/dev/null
  local has_pv="$?"

  mkdir -p logs &&
  touch "logs/$fn.log" &&
  \
  if [ "$has_pv" -eq 0 ]; then
    # Magic progress bars
    $fn 2>&1 | \
      pv -petl -N "$fn" -s "`cat "counts/$fn.count"`" > "logs/$fn.log"
    rv="$?"

    local ts="`date '+%Y-%m-%d %H:%M:%S'`"
    ansi_previous_line

    if [ "$rv" -eq 0 ]; then
      echo "Task '$fn' completed successfully at $ts UTC."
    else
      echo "Task '$fn' failed at $ts UTC."
    fi

  else
    # Fallback prograss information
    echo -n "Running '$fn'... " &&
    $fn &> "logs/$fn.log"
    rv="$?"

    if [ "$rv" -eq 0 ]; then
      echo 'done.'
    else
      echo 'failed.'
    fi
  fi

  return "$rv"
}

ansi_previous_line() {

  echo -ne '\033[1F\033[0J'
}

update_apt() {

  export DEBIAN_FRONTEND=noninteractive &&
  apt-get -q update &&
  apt-get -q -y autoremove
}

install_pv() {

  export DEBIAN_FRONTEND=noninteractive &&
  apt-get -q -y -o Dpkg::Options::="--force-confnew" install make pv
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

install_nvm() {

  bash contrib/nvm/install.sh &&
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
}

install_node() {

  nvm install "$NODE_VERSION"
}

install_iniedit() {

  npm install -g '@castlelemongrab/iniedit'
}

install_djbdns() {

  (cd downloads &&
    curl -LO# 'https://cr.yp.to/djbdns/djbdns-1.05.tar.gz' &&
    tar xvzf 'djbdns-1.05.tar.gz' &&
    (cd 'djbdns-1.05' &&
     echo gcc -O2 -include /usr/include/errno.h > conf-cc &&
     make && make setup check &&
     for u in dnscache tinydns; do
       groupadd -f "$u" &&
       id -u "$u" &>/dev/null \
         || useradd -d /var/empty -g "$u" -MNrs /bin/true "$u" || return 1
     done))
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

  log install_pv &&
  log update_apt &&
  log install_apt &&
  log install_nvm &&
  log install_node &&
  log install_iniedit &&
  log install_djbdns &&
  log deploy_dnscache &&
  \
  echo -n 'Success; rebooting in 60 seconds... ' &&
  sync && sleep 60 && sync &&
  echo 'rebooting.' &&
  \
  reboot
}

install_all "$@"

