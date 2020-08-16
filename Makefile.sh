#!/bin/bash

path="`realpath "$0"`" &&
dirname="`dirname "$path"`" &&
\
cd "$dirname" &&
source src/tinywire.sh &&
\
install_all "$@"

