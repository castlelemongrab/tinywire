#!/bin/bash

if [ "`id -u`" -ne 0 ]; then
  echo 'This command must be run as root.' >&2
  exit 1
fi

path="`realpath "$0"`" &&
dirname="`dirname "$path"`" &&
\
cd "$dirname" &&
source src/tinywire.sh &&
\
install_all "$@"

