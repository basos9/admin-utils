#!/bin/bash
#1.2
BASE=$(readlink -f `dirname $0`)

USER=backer
ZIP=gzip
ROOT=/
STAMP=`date +%Y%m%d-%H%M`

usage()
{
  cat >&2 <<EOF
  Usage: $0 [opt] <outd|->
  Output folder to create system backup, user via -u, e.g. $0 /var/lib/backups
  OR - to pipe to stdout e.g. $0 - bzip2 | ssh -p 2222 user@host 'cat > /mnt/data/host.tbz'
   -z <zipprog>, default gzip
   -u <user> 
   -t <tarargs>
   -r <[user@]hostname or ssh://[user@]hostname[:port]>
   -b <root> default /
EOF
}

XARGS=
while getopts “hz:t:u:r:b:” OPTION
do
     case $OPTION in
         h)  usage; exit 1 ;;
         z)  ZIP=$OPTARG  ;;
         t)  XARGS="$XARGS $OPTARG" ;;
         u)  USER=$OPTARG ;;
         r)  SSH=$OPTARG ;;
         b)  ROOT="$OPTARG" ;;
         ?)  usage; exit ;;
     esac
done
shift $(( $OPTIND - 1 ))
set -o pipefail

OUTD="$1"
shift 1
EXT=tgz
if [[ $ZIP =~ bz ]]; then
  EXT=tbz
fi
NAMEF=sys-full-`hostname`-$STAMP.$EXT
NAME=$NAMEF.wip
TAROPTS="c -p --ignore-failed-read \
        --exclude=./proc --exclude=./sys --exclude=./dev --exclude=./mnt/*
        --exclude='./root/w' --exclude='./var/*img' \
        --exclude=./var/lib/backups  $XARGS -C $ROOT ." 
DEST=$OUTD/$NAME
[ -z "$OUTD" ] && usage && exit 4
if [ "$OUTD" != "-" ] && [ -z "$SSH" ]; then
  echo "FILE mode, zip $ZIP, user $USER, Taring to $DEST " >&2
  if ! [ -d "$OUTD" ]; then
    echo "** DIR not found $OUTD" >&2
    exit 4
  fi
  DESTP=$(echo $DEST | sed 's/^\///')
  set -x
  ionice -n 7 tar "$TAROPTS" --exclude="$DESTP" | \
    /bin/bash -c "su $USER -c \"nice $ZIP >$DEST\" &&
    mv $DEST $OUTD/$NAMEF"
  r=$?
  set +x
elif [ "$OUTD" != "-" ] && [ -n "$SSH" ]; then
  echo "REMOTE mode, zip $ZIP, ssh to $SSH, taring to remote dest $DEST" >&2
  set -x
  ionice -n 7 tar $TAROPTS | \
    nice $ZIP | \
    ssh $SSH "cat >$DEST" && ssh $SSH "mv $DEST $OUTD/$NAMEF"
  r=$?
  set +x
  
else
 echo "STDOUT mode, zip $ZIP, tarring" >&2
  set -x
  ionice -n 7 tar $TAROPTS | \
    nice $ZIP
  r=$?
  set +x
fi
# --ignore-command-error --ignore-failed-read
if [ "$r" != "0" ]; then 
  echo "** FAILED" >&2; exit $r;
else
  echo "* SUCCESS" >&2
fi
