#!/usr/bin/env bash

source src/iniedit.sh
source config/tinywire.conf

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
      pv -petl -N "$fn" -s "`cat "stats/$fn.count"`" > "logs/$fn.log"
    rv="${PIPESTATUS[0]}"

    local ts="`date '+%Y-%m-%d %H:%M:%S'`"
    ansi_previous_line

    if [ "$rv" -eq 0 ]; then
      echo "Task '$fn' completed successfully at $ts UTC."
    else
      echo "Task '$fn' failed at $ts UTC."
    fi

  else
    # Fallback progress information
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
    ipcalc wireguard wireguard-dkms zlib1g-dev uuid-dev libblkid-dev \
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

deploy_wireguard() {

  local POSTUP="iptables -A FORWARD -i %i -j ACCEPT;"
  POSTUP="$POSTUP iptables -A FORWARD -o %i -j ACCEPT;"
  POSTUP="$POSTUP iptables -t nat -A POSTROUTING -o $IF -j MASQUERADE"

  local POSTDOWN="iptables -D FORWARD -i %i -j ACCEPT;"
  POSTDOWN="$POSTDOWN iptables -D FORWARD -o %i -j ACCEPT;"
  POSTDOWN="$POSTDOWN iptables -t nat -D POSTROUTING -o $IF -j MASQUERADE"

  umask 0277 &&
  wg genkey | ./bin/iniedit add -f /dev/null -s Interface \
    -l "ListenPort = $PORT" -l 'PrivateKey' \
    -l "Address = $WIREGUARD_IP/$WIREGUARD_NETMASK" \
    -l "PostUp = $POSTUP" -l "PostDown = $POSTDOWN" > "$WIREGUARD_CONFIG"
}

wireguard_add_peer()
{
  local name="`basename "$1"`"
  local ip="$2"

  if [ -z "$name" ]; then
    return 1
  fi

  if [ -z "$ip" ]; then
    return 2
  fi

  umask 0277 &&
  trap "rm -f '$key_tmp' '$server_config_tmp' '$peer_config_tmp'" EXIT &&
  \
  local key_tmp="`tempfile -m 0400`" &&
  local peer_config_tmp="`tempfile -m 0400 -d temp -s .ini`" &&
  local server_config_tmp="`tempfile -m 0400 -d temp -s .ini`" &&
  \
  # Peer private key
  wg genkey > "$key_tmp" &&
  \
  # Modify server configuration
  wg pubkey < "$key_tmp" | ./bin/iniedit add \
    -f "$WIREGUARD_CONFIG" -s Peer -c "$name" \
    -l PublicKey -l AllowedIPs="$ip/32" > "$server_config_tmp" && \
  \
  # Create peer configuration file
  (./bin/iniedit add -f /dev/null \
     -s Interface -c "$name" -l "Address = $2" \
       -l "DNS = $WIREGUARD_DNS_IP" -l PrivateKey < "$key_tmp" &&
   ./bin/iniedit read -f "$WIREGUARD_CONFIG" \
     -s Interface -l PrivateKey | wg pubkey | \
   ./bin/iniedit add -f /dev/null \
     -s Peer -l "Endpoint = $DOMAIN:$PORT" \
     -l 'AllowedIPs = 0.0.0.0/0, ::/0' \
     -l 'PersistentKeepalive=60' -l PublicKey) > "$peer_config_tmp"

  if [ "$?" -eq 0 ]; then
    # Print peer configuration
    echo && qrencode -t ansiutf8 < "$peer_config_tmp" &&
    echo && cat "$peer_config_tmp" &&
    \
    # Commit server changes
    mv "$server_config_tmp" "$WIREGUARD_CONFIG" &&
    wg addconf wg0 <(wg-quick strip wg0)
  fi

  local rv="$?"
  rm -f "$key_tmp" "$server_config_tmp" "$peer_config_tmp"
  return "$rv"
}

install_all () {

  log install_pv &&
  log update_apt &&
  log install_apt &&
  log install_nvm &&
  log install_node &&
  log install_iniedit &&
  log deploy_wireguard &&
  log install_djbdns &&
  log deploy_dnscache &&
  \
  echo -n 'Success; rebooting in 60 seconds... ' &&
  sync && sleep 60 && sync &&
  echo 'rebooting.' &&
  \
  reboot
}

