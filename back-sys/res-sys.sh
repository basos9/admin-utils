#!/bin/bash
#v1.2
SRC=.
PORT=22
XARG=""
DO=0
TWOF=
BANG=
DO1=0
DO2=0
DO3=0
DO4=0
DOA=1

usage()
{
  cat >&2 <<EOF
  Usage: $0 [opt] <[USER@]HOST> <DEST>
   -p <port>, default $PORT
   -c  DO it, else dry run
   -v  verbose
   -d  Delete
   -o  Extra rsync options
   -S  SRC dir, default $BASE
   -T  Run two phase, excluding /bin /sbin /lib
   -B  BANG! Dont stop on errors
   -1  Prepare only, copy to /sysold and /sysnew (Step 1)
   -3  Copy phanse only (Step 3)
   -4  FIX only (Step 4)"
EOF
   ## -r  Running system, exclude things
}

while getopts “hp:cvdo:S:TB1234” OPTION
do
     case $OPTION in
         h)  usage; exit 1 ;;
         p)  PORT=$OPTARG  ;;
         c)  DO=1 ;;
         v)  XARG="$XARG -v" ;;
         d)  XARG="$XARG --delete" ;;
         o)  XARG="$XARG $OPTARG";;
         S)  SRC="$OPTARG" ;;
         T)  TWOF=1 ;;
         B)  BANG=1 ;;
         1)  DOA=0; DO1=1 ;;
         2)  DOA=0; DO2=1 ;;
         3)  DOA=0; DO3=1 ;;
         4)  DOA=0; DO4=1 ;;
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

if [[ $DOA = 1 ]]; then
  DO1=1; DO2=1; DO3=1; DO4=1;
fi

DOD=DRY
if [[ $DO = 1 ]]; then DOD=DO; fi
echo "This is $DOD run 
  xfer $SRC to $DST root $DST, 
  PHASE1: $DO1, PHASE2: $DO2, PHASE3: $DO3, PHASE4: $DO4
  TWOPH $TWOF, BATCH $BANG,  
  rsync args $BARG $XARG"


A=y
if [[ $BANG != 1 ]]; then
  read -p "You ok ?" A
fi
if ! [[ $A =~ y|Y ]]; then
  exit  3
fi




if [[ $DO1 = 1 ]]; then
  echo ""
  echo "*** STEP 1a: SSH to $SSH to prepare /sysold and /sysnew (backup /etc)"
  set -x
  ssh -p $PORT $SSH "set -e; echo '* Preparing $DST sysold sysnew'; mkdir -p $DST/sysold; mkdir -p $DST/sysnew; if [ -d $DST/sysold/etc ]; then echo \"Already existing $DST/sysold/etc. Bye\"; exit 4; fi; cp -a $DST/etc $DST/sysold; echo 'Ok'"
  RT=$?; set +x
  [ "$RT" != "0" ] && ARET=$RT

  if [ "$ARET" != "0" ];  then 
    A=y
    if [[ $BANG != 1 ]]; then
      read -p "Maybe not or ?" A
    fi
    if ! [[ $A =~ y|Y ]]; then
      exit 4
    fi
  fi

  echo ""
  echo "*** STEP 1b: RSYNC $SRC/etc to $DEST/sysnew for reference"
  set -x
  rsync $BARG --delete $SRC/etc/ $DEST/sysnew/etc/ -e "ssh -p $PORT"
  RT=$?;   set +x
  [ "$RT" != "0" ] && ARET=$RT
fi

if [[ $TWOF = 1 ]] && [[ $DO2 = 1 ]]; then
  echo
  echo "*** STEP 2 (for two phase): RSYNC $SRC/bin sbin lib* to $DEST/sysnew for reference"
  rsync $BARG --delete --include '/bin*' --include '/sbin*' --include '/lib*' --exclude '/*' -e "ssh -p $PORT" $SRC $DEST/sysnew/
  RT=$?;   set +x
  [ "$RT" != "0" ] && ARET=$RT

  XARG="$XARG --exclude '/bin*' --exclude '/sbin*' --exclude '/lib*' "
fi
    
if [ "$ARET" != "0" ];  then 
  A=y
  if [[ $BANG != 1 ]]; then
    read -p "Maybe not or ?" A
  fi
  if ! [[ $A =~ y|Y ]]; then
    exit 4
  fi
fi


if [[ $TWOF != 1 ]]; then
  echo "* One phase (same system type mode) "
else
  echo "* TWO PHASE (frankenstein mode)"
  echo "* WARNING: This is trully experimental"
  echo "* Will exclude also stuff /bin /sbin /lib* xarg: $XARG"
fi


if [[ $DO3 = 1 ]]; then
  echo ""
  if [[ $DO = 1 ]]; then
    echo "*** NOW WE ARE MAKING A NEW SYSTEM"
  fi
  echo "*** STEP 3: RSYNC $SRC to $SSH:$DEST port $PORT, aHSKDz (all, hard links, sparse, keep dirlinks, dev & specials, zip), exc /etc/fstab, /etc/network/interfaces"
  set -x
  rsync $BARG --exclude '/sys*' --exclude '/proc/' --exclude '/dev/' --exclude '/mnt/' --exclude '/etc/fstab' --exclude '/etc/network/interfaces'  --exclude '/etc/sysconfing/network-scripts*' $XARG -e "ssh -p $PORT" $SRC/ $DEST
  RT=$?;   set +x
  [ "$RT" != "0" ] && ARET=$RT

  echo "*** POST: DIFFING"
  ssh -p $PORT $SSH -o StrictHostKeyChecking=no "set -x; diff -u $DST/etc/fstab $DST/sysnew/etc/fstab; diff -u $DST/etc/network/interfaces $DST/sysnew/etc/network/interfaces"

  echo "*** SYNCED $ARET ***"
  echo "*** Check and sync them manually !!:"
  echo "*
GRUB-INSTALL 
EXCLUDED /etc/fstab
EXCLUDE /etc/network/interfaces (debian) or /etc/sysconfig/network-scripts* (rhel)
ACCESS check /etc/shadow and/or /root/.ssh/authorized_keys"
  if [[ $TWOF = 1 ]]; then
    echo "* Hopefully you already have a session and in addition to other tasks try to
- move back base utils (/bin /sbin/ lib*) from /sysnew to / (for stuff excluded)"
  fi

fi

if [[ $DO4 = 1 ]]; then
  echo
  echo "*** STEP 4: POST: fixings"
  ssh -p $PORT $SSH  -o StrictHostKeyChecking=no 'set -x; hostname;
 root=`cat /proc/mounts  | awk '"'"' $2 ~ /^\/$/ { print $1 }'"'"' | sed '"'"'s/[0-9]*$//'"'"'`
 if [ -n "$root" ]; then grub-install $root; fi
 if grep debian /etc/os-release; then update-grub; fi
 if [ "'$BANG'" != "1" ]; then
   echo "Want to update root passwd? ";  read A
   if [ "$A" = "y" ]; then passwd root; fi
 fi
 echo "*** logout from `hostname -f`"'

fi


echo "CODE: $ARET"
