#!/bin/bash
#v1.1
SRC=.
PORT=22
XARG=""
DO=0
TWOF=
FIXO=
usage()
{
  cat >&2 <<EOF
  Usage: $0 [opt] <[USER@]HOST> <DEST>
   -p <port>, default $PORT
   -v  verbose
   -c  DO it, else dry run
   -d  Delete
   -S  SRC dir, default $BASE
   -B  BANG! Dont stop on errors
   -o  Extra rsync options
   -t  Run two phase, excluding /bin /sbin /lib
   -r  Running system, exclude things
   -f  FIX only (Step 4)"
EOF
}

while getopts “hp:crvdo:S:2Bf” OPTION
do
     case $OPTION in
         h)  usage; exit 1 ;;
         p)  PORT=$OPTARG  ;;
         v)  XARG="$XARG -v" ;;
         c)  DO=1 ;;
         o)  XARG="$XARG $OPTARG";;
         d)  XARG="$XARG --delete" ;;
         S)  SRC="$OPTARG" ;;
         2)  TWOF=true ;;
         B)  BANG=true ;;
         f)  FIXO=true ;;
         #r)  XARG="$XARG --exclude=/etc/fstab --exclude=/etc/mtab --exclude=/etc/shadow --exclude=/etc/passwd --exclude=/etc/sysconfig/network* --exclude=/tmp  --exclude=/var/log --include=/var/lib/rpm --include=/var/lib/yum --exclude=/var/lib/* --exclude=/var/spool --exclude=/var/lock --exclude=/dev  --exclude=/root/.ssh --exclude=/root/w --exclude=/var/run " ;;
         ?)  usage; exit ;;
     esac
done
shift $(( $OPTIND - 1 ))

SSH=$1
DST=$2
DEST=$SSH:$DST

([ -z "$DEST" ] || [ -z $SSH ] ) && usage && exit 2

[ "$DO" != "1" ] && XARG="$XARG -n"
ARET=0


## -H Hard Links
## -K This  option  causes the receiving side to treat a symlink to a directory as though it were a real directory, but only if it matches a real directory from the sender. 
BARG="--super -aSDz"

echo "Restore live system from backup (tar) with rsync
It would be more covenient to setup ssh ControlMaster channel. 
Run the following:

cat >> ~/.ssh/config <'EOF'
ControlPath ~/.ssh-%C 
ControlPersist 30
ControlMaster auto
EOF

"

echo "This is DO ${DO} run 
  xfer $SRC to $DST root $DST, 
  TWOPH $TWOF, BATCH $BANG, FIXONL $FIXO 
  rsync args $BARG $XARG"


A=y
if [[ $BANG != true ]]; then
  read -p "You ok ?" A
fi
if ! [[ $A =~ y|Y ]]; then
  exit  3
fi


dofix() {
  echo "*** STEP4: POST: fixings"
  ssh -p $PORT $SSH  -o StrictHostKeyChecking=no 'set -x;
 root=`cat /proc/mounts  | awk '"'"' ~ /^\/$/ { print }'"'"' | sed '"'"'s/[0-9]*$//'"'"'`
 if [ -n "$root\" ]; then grub-install $root; fi
 if grep debian /etc/os-release; then update-grub; fi'
}

if [[ $FIXO = true ]]; then
  echo "** SKIPPING SYNC, fast forward to step 4 (fixings)"
  dofix
  exit $?
fi

echo ""
echo "*** STEP1: SSH to $SSH to prepare sysold, backup /etc"
set -x
ssh -p $PORT $SSH "set -e; echo '* Preparing $DST sysold sysnew'; mkdir -p $DST/sysold; mkdir -p $DST/sysnew; if [ -d $DST/sysold/etc ]; then echo \"Already existing $DST/sysold/etc. Bye\"; exit 4; fi; cp -a $DST/etc $DST/sysold; echo 'Ok'"
RT=$?; set +x
[ "$RT" != "0" ] && ARET=$RT

  if [ "$ARET" != "0" ];  then 
    A=y
    if [ "$BANG" != "true" ]; then
      read -p "Maybe not or ?" A
    fi
    if ! [[ $A =~ y|Y ]]; then
      exit 4
    fi
  fi

  echo ""
  echo "*** STEP 2: RSYNC $SRC/etc to $DEST/sysnew for reference"
  set -x
  rsync $BARG --delete $SRC/etc/ $DEST/sysnew/etc/ -e "ssh -p $PORT"
  RT=$?;   set +x
  [ "$RT" != "0" ] && ARET=$RT

  if [[ $TWOF = true ]]; then

    echo "*** STEP 2.1 (for two phase): RSYNC $SRC/bin sbin lib* to $DEST/sysnew for reference"
    rsync $BARG --delete --include '/bin*' --include '/sbin*' --include '/lib*' --exclude '/*' -e "ssh -p $PORT" $SRC $DEST/sysnew/
    RT=$?;   set +x
    [ "$RT" != "0" ] && ARET=$RT

    XARG="$XARG --exclude '/bin*' --exclude '/sbin*' --exclude '/lib*' "
  fi
    
  if [ "$ARET" != "0" ];  then 
    A=y
    if [ "$BANG" != "true" ]; then
      read -p "Maybe not or ?" A
    fi
    if ! [[ $A =~ y|Y ]]; then
      exit 4
    fi
  fi


if [[ $TWOF != true ]]; then
  echo "* One phase (same system type mode) "
else
  echo "* TWO PHASE (frankenstein mode)"
  echo "* WARNING: This is trully experimental"
  echo "* Will exclude also stuff /bin /sbin /lib* xarg: $XARG"
fi


  echo ""
  if [[ $DO = 1 ]]; then
    echo "*** NOW WE ARE MAKING A NEW SYSTEM"
  fi
  echo "*** STEP3: RSYNC $SRC to $SSH:$DEST port $PORT, aHSKDz (all, hard links, sparse, keep dirlinks, dev & specials, zip), exc /etc/fstab, /etc/network/interfaces"
  set -x
  rsync $BARG --exclude '/sys*' --exclude '/proc/' --exclude '/dev/' --exclude '/mnt/' --exclude '/etc/fstab' --exclude '/etc/network/interfaces'  --exclude '/etc/sysconfing/network-scripts*' $XARG -e "ssh -p $PORT" $SRC/ $DEST
  RT=$?;   set +x
  [ "$RT" != "0" ] && ARET=$RT

  ## STEP4
  dofix

  echo "*** POST: DIFFING"
  ssh -p $PORT $SSH -o StrictHostKeyChecking=no "set -x; diff -u $DST/etc/fstab $DST/sysnew/etc/fstab; diff -u $DST/etc/network/interfaces $DST/sysnew/etc/network/interfaces"

  echo "*** SYNCED $ARET ***"
  echo "*** EXCLUDED (Check and sync them manually !!):"
  echo "*
/etc/fstab
/etc/network/interfaces (debian) or /etc/sysconfig/network-scripts* (rhel)"
  echo "** ALSO dont forget to check /etc/shadow and /root/.ssh/authrorized_keys, and update-grub!!"
  if [[ $TWOF = true ]]; then
    echo "* Hopefully you already have a session and try to
- fix booting (grub), network, access (shadow), and move back base utils  from /sysnew to / (for stuff excluded)"
  fi


echo "CODE: $ARET"
