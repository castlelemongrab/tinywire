#!/bin/sh

self="`realpath "$0"`"
dirname="`dirname "$self"`"
cd "$dirname" && bash ./src/main.sh

