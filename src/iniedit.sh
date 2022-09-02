#!/bin/bash

install_nvm() {

  bash contrib/nvm/install.sh
}

initialize_nvm() {

  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
}

install_node() {

  initialize_nvm &&
  nvm install "$NODE_VERSION"
}

install_iniedit() {

  initialize_nvm &&
  npm install '@castlelemongrab/iniedit'
}

iniedit() {

  initialize_nvm &&
  local node="`which node`" &&
  local path="`realpath "$node"`" &&
  local dirname="`dirname "$path"`" &&
  local script='node_modules/@castlelemongrab/iniedit/bin/iniedit'

 "$node" "$script" "$@"
}

