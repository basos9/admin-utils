#!/bin/bash

BASE=$(readlink -f $(dirname $0))

cp -fv $BASE/monact /usr/local/sbin
cp -fv $BASE/monact@.service /etc/systemd/system
mkdir -p /usr/local/share/monact
cp -fv $BASE/*.check /usr/local/share/monact
cp -fv $BASE/*.act /usr/local/share/monact
mkdir -p /etc/monact
cp -fv $BASE/example.conf /etc/monact/
systemctl daemon-reload
echo "To create a monact service
  cp /etc/monact/example.conf /etc/monact/<serviceid>.conf
  edit /etc/monact/<serviceid>
  define MONACT_CHECK=<checkid>
  define MONACT_ACTION=<actionio>
  define check variables from /usr/local/share/monact/<checkid>.check
  define action variables from /usr/local/share/monact/<actionid>.act
"
