#!/bin/bash
#1.2
BASE=$(readlink -f `dirname $0`)

USER=backer
ZIP=gzip
ROOT=/
STAMP=`date +%Y%m%d-%H%M`
LOCK=/tmp/`basename $0`back.lock

usage()
{
  cat >&2 <<EOF
  Usage: $0 [opt] <outd|->
  Output folder to create system backup, user via -u, e.g. $0 /var/lib/backups
  OR - to pipe to stdout e.g. $0 - bzip2 | ssh -p 2222 user@host 'cat > /mnt/data/host.tbz'
   -z <zipprog>, default gzip
   -u <user> 
   -t <tarargs>
   -W disable tar warnings for changed files (disables --warning no-file-ignored --warning no-file-changed)
   -E exact, do not ignore tar exit code 1, meaning some files changed while being archived
   -r <[user@]hostname or ssh://[user@]hostname[:port]>
   -b <root> default /
EOF
}

XARGS=
TWARGS="" 
SKIPE1=1
while getopts “hz:t:u:r:b:WE” OPTION
do
     case $OPTION in
         h)  usage; exit 1 ;;
         z)  ZIP=$OPTARG  ;;
         t)  XARGS="$XARGS $OPTARG" ;;
         u)  USER=$OPTARG ;;
         r)  SSH=$OPTARG ;;
         b)  ROOT="$OPTARG" ;;
         W)  TWARGS="--warning no-file-ignored --warning no-file-changed" ;;
         E)  SKIPE1=0 ;;
         ?)  usage; exit ;;
     esac
done
shift $(( $OPTIND - 1 ))
set -o pipefail

OUTD="$1"
shift 1
[ -z "$OUTD" ] && usage && exit 4

if [ -f $LOCK ]; then
  echo "[*] Lockfile $LOCK exitsts. Bye" >&2
  exit 3
fi
onex()
{
  echo "[+] Exiting & unlocking" >&2
  rm -f $LOCK || true
}
trap onex EXIT
touch $LOCK || exit 4

EXT=tgz
if [[ $ZIP =~ bz ]]; then
  EXT=tbz
fi
NAMEF=sys-full-`hostname`-$STAMP.$EXT
NAME=$NAMEF.wip
DEST=$OUTD/$NAME
if [ "$OUTD" != "-" ] && [ -z "$SSH" ]; then
  DESTP=$(echo $DEST | sed 's/^\///')
  XARGS="--exclude="$DESTP"  $XARGS"
fi
TAROPTS="c -p $TWARGS
        --exclude=./proc --exclude=./sys --exclude=./dev --exclude=./mnt/*
        --exclude='./root/w' --exclude='./var/*img' 
        --exclude=./var/lib/backups --exclude='./$LOCK' $XARGS -C $ROOT ." 

getps(){
  local total=${#R[*]}
  local ret=0
  for (( i=0; i<=$(( $total -1 )); i++ ))
  do
    rt=${R[$i]}
    if [ $i -eq 0 ] && [ "$rt" = "1" ] && [ "$SKIPE1" = "1" ]; then
      rt=0
      echo "[*] Ignoring first command (tar) exit code of 1" >&2
    fi
    if [ "$rt" != "0" ]; then ret=$rt; fi
  done
  echo "[+] Collected status of $total commands is $ret  (${R[@]})" >&2
  return $ret
}

if [ "$OUTD" != "-" ] && [ -z "$SSH" ]; then
  echo "[+] FILE mode, zip $ZIP, user $USER, Taring to $DEST, ignore changed $SKIPE1 " >&2
  if ! [ -d "$OUTD" ]; then
    echo "[*] DIR not found $OUTD" >&2
    exit 4
  fi
  set -x
  ionice -n 7 tar  $TAROPTS | \
    /bin/bash -c "su $USER -c \"nice $ZIP >$DEST\" &&
    mv $DEST $OUTD/$NAMEF"
  r1=$?  R=(${PIPESTATUS[@]})
  set +x
  getps; r=$?

elif [ "$OUTD" != "-" ] && [ -n "$SSH" ]; then
  echo "[+] REMOTE mode, zip $ZIP, ssh to $SSH, taring to remote dest $DEST, ignore changed $SKIPE1" >&2
  set -x
  ionice -n 7 tar $TAROPTS | \
    nice $ZIP | \
    ssh $SSH "cat >$DEST" && ssh $SSH "mv $DEST $OUTD/$NAMEF"
  r1=$?  R=(${PIPESTATUS[@]})
  set +x
  getps; r=$?

else
 echo "[+] STDOUT mode, zip $ZIP, tarring, ignore changed $SKIPE1" >&2
  set -x
  ionice -n 7 tar $TAROPTS | \
    nice $ZIP
  r1=$?  R=(${PIPESTATUS[@]})
  set +x
  getps; r=$?
fi
# --ignore-command-error --ignore-failed-read
if [ "$r" != "0" ]; then 
  echo "[*] FAILED (code $r) ($r1)" >&2; exit $r;
else
  echo "[+] SUCCESS (code $r) ($r1)" >&2
fi
