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
   -e <exclude> pass --exclude to tar, note add leading slash e.g. /var/lib
   -x pass --one-file-system to tar
   -W disable tar warnings for changed files (disables --warning no-file-ignored --warning no-file-changed)
   -E exact, do not ignore tar exit code 1, meaning some files changed while being archived
   -r <[user@]hostname or ssh://[user@]hostname[:port]>
   -H disable ssh option StrictHostKeyChecking=accept-new, which accepts unknown hosts (for -r remode mode)
   -P enable password authentication
   -b <root> default /
EOF
}

techo()
{
  echo "[`date +%Y%m%d-%H%M`][`hostname -f`][`basename $0`] $@"
}
XARGS=
TWARGS="" 
SKIPE1=1
HOSTK=1
PASSAUTH=
SSHOPTS=
while getopts “hz:t:u:r:b:WEHPe:x” OPTION
do
     case $OPTION in
         h)  usage; exit 1 ;;
         z)  ZIP=$OPTARG  ;;
         t)  XARGS="$XARGS $OPTARG" ;;
         e)  XARGS="$XARGS --exclude '${OPTARG/#\//.\/}'";;
         x)  XARGS="$XARGS --one-file-system" ;;
         u)  USER=$OPTARG ;;
         r)  SSH=$OPTARG ;;
         b)  ROOT="$OPTARG" ;;
         W)  TWARGS="--warning no-file-ignored --warning no-file-changed" ;;
         E)  SKIPE1=0 ;;
         H)  HOSTK=0 ;;
         P)  PASSAUTH=1 ;;
         ?)  usage; exit ;;
     esac
done
shift $(( $OPTIND - 1 ))
set -o pipefail

OUTD="$1"
shift 1
[ -z "$OUTD" ] && usage && exit 4

if [ -f $LOCK ]; then
  techo "[*] Lockfile $LOCK exitsts. Bye" >&2
  exit 3
fi
onex()
{
  techo "[+] Exiting & unlocking" >&2
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
  DESTP=$(echo $DEST | sed 's/^\//.\//')
  XARGS="--exclude=\"$DESTP\"  $XARGS"
fi
TAROPTS="c -p $TWARGS
        --exclude=./proc --exclude=./sys
        --exclude='./mnt/*' --exclude='./media/*' --exclude=./var/lib/backups
        --exclude='./root/w' --exclude='./var/swap*' 
        --exclude='./$LOCK' $XARGS -C $ROOT ." 

getps(){
  local total=${#R[*]}
  local ret=0
  for (( i=0; i<=$(( $total -1 )); i++ ))
  do
    rt=${R[$i]}
    if [ $i -eq 0 ] && [ "$rt" = "1" ] && [ "$SKIPE1" = "1" ]; then
      rt=0
      techo "[*] Ignoring first command (tar) exit code of 1" >&2
    fi
    if [ "$rt" != "0" ]; then ret=$rt; fi
  done
  techo "[+] Collected status of $total commands is $ret  (${R[@]})" >&2
  return $ret
}

if [ "$OUTD" != "-" ] && [ -z "$SSH" ]; then
  techo "[+] FILE mode, zip $ZIP, user $USER, Taring to $DEST, ignore changed $SKIPE1 " >&2
  if ! [ -d "$OUTD" ]; then
    techo "[*] DIR not found $OUTD" >&2
    exit 4
  fi
  set -x
  ionice -n 7 tar  $TAROPTS | \
    /bin/bash -c "su $USER -c \"nice $ZIP >$DEST\""
  r1=$?  R=(${PIPESTATUS[@]})
  set +x
  getps; r=$?
  if [[ $r = 0 ]]; then
    mv "$DEST" "$OUTD/$NAMEF"
    r=$?
  fi

elif [ "$OUTD" != "-" ] && [ -n "$SSH" ]; then
  techo "[+] REMOTE mode, zip $ZIP, ssh to $SSH, taring to remote dest $DEST, ignore changed $SKIPE1, accept new hosts: $HOSTK" >&2
  if [ "$HOSTK" = "1" ]; then
    SSHOPTS="${SSHOPTS}${SSHOPTS:+ }-oStrictHostKeyChecking=accept-new"
  fi
  if [ "$PASSAUTH" != "1" ]; then
    SSHOPTS="${SSHOPTS}${SSHOPTS:+ }-oPasswordAuthentication=no"
  fi
 
  set -x
  ionice -n 7 tar $TAROPTS | \
    nice $ZIP | \
    ssh $SSHOPTS $SSH "[ -d \"$OUTD\" ] || { echo \"Creating dir $OUTD\" && mkdir -p \"$OUTD\"; }; cat >$DEST"
  r1=$?  R=(${PIPESTATUS[@]})
  set +x
  if [ ${R[2]} == 255 ]; then
    techo "[*] Maybe ssh public key not registered for $SSH. Dumping key." >&2
    set -x
    cat ~/.ssh/id_rsa.pub >&2
    set +x
  fi
  getps; r=$?
  if [[ $r = 0 ]]; then
    ssh $SSH $SSHOPTS "mv $DEST $OUTD/$NAMEF"
    r=$?
  fi

else
 techo "[+] STDOUT mode, zip $ZIP, tarring, ignore changed $SKIPE1" >&2
  set -x
  ionice -n 7 tar $TAROPTS | \
    nice $ZIP
  r1=$?  R=(${PIPESTATUS[@]})
  set +x
  getps; r=$?
fi
# --ignore-command-error --ignore-failed-read
if [ "$r" != "0" ]; then 
  techo "[*] FAILED (code $r) ($r1)" >&2; exit $r;
else
  techo "[+] SUCCESS (code $r) ($r1)" >&2
fi
