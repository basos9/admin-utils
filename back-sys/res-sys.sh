#!/bin/bash
#v1.3
SRC=.
PORT=22
XARG=""
SKARG=
DO=0
TWOF=
BANG=
DO1=0
DO2=0
DO3=0
DO4=0
DOA=1
DES=
UN=
CMD="$0 $@"
usage()
{
  cat >&2 <<EOF
  Usage: $0 [opt] <[USER@]HOST> <DEST>
   -p <port>, default $PORT
   -c  DO it, else dry run
   -v  verbose
   -d  Delete
   -e  Rsync --exclude  (e.g. -e '/vagrant*')
   -o  Extra rsync options
   -O  Extra ssh/scp options
   -H  SSH/SCP no strictHostKeyChecking
   -X  SSH/SCP no Host Checking UserKnownHostsFile=/dev/null
   -u  UNSAFE mode, good for same env restoring, DO NOT exclude running kernel, network config (interfaces, resolv.conf) , fstab
   -S  SRC dir, default $BASE
   -T  Run two phase, excluding /bin /sbin /lib, **EXPERIMENTAL CROSS DISTRO**
   -B  BANG! Dont stop on errors
   -1  Prepare only, copy to /sysold and /sysnew (Step 1)
   -3  Copy only (Step 3)
   -4  FIX only (Step 4)"
EOF
   ## -r  Running system, exclude things
}

while getopts “hp:cvdo:S:TB1234HO:e:uX” OPTION
do
     case $OPTION in
         h)  usage; exit 1 ;;
         p)  PORT=$OPTARG  ;;
         c)  DO=1 ;;
         v)  XARG="$XARG -v" ; DES="$DES VERB 1" ;;
         d)  XARG="$XARG --delete" DES="$DES DEL 1";;
         e)  XARG="$XARG --exclude=\"$OPTARG\"";;
         o)  XARG="$XARG $OPTARG";;
         O)  SKARG="$SKARG $OPTARG";;
         H)  SKARG="$SKARG -oStrictHostKeyChecking=no"; DES="$DES STRICTH 0" ;;
         X)  SKARG="$SKARG -oUserKnownHostsFile=/dev/null"; DES="$DES NOH 0" ;;
         S)  SRC="$OPTARG" ;;
         u)  UN=1 ; DES="$DES UNSAFE mode (same ENV)" ;;
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


ARET=0

## -H Hard Links
## -K This  option  causes the receiving side to treat a symlink to a directory as though it were a real directory, but only if it matches a real directory from the sender. 
#  echo "*** STEP 3: RSYNC $SRC to $SSH:$DEST port $PORT, aHSKDz (all, hard links, sparse, keep dirlinks, dev & specials, zip)"
BARG="--super --numeric-ids -aSDz"

[ "$DO" != "1" ] && BARG="$BARG -n"

SARG="$SKARG -p $PORT"
SARG="$SARG -oControlPath=~/.ssh-res-sys-%C -oControlPersist=60 -oControlMaster=auto"
CSARG="$SKARG -P $PORT"
CSARG="$CSARG -oControlPath=~/.ssh-res-sys-%C -oControlPersist=60 -oControlMaster=auto"


echo "Restore live system from backup (tar) with rsync.
This script uses ssh ControlMaster channel in ~/.ssh-res-sys-%C.
"

#If you would like to setup ssh ControlMaster channel. 
#Run the following:
#
#cat >> ~/.ssh/config <'EOF'
#ControlPath ~/.ssh-%C 
#ControlPersist 30
#ControlMaster auto
#EOF

if [[ $DOA = 1 ]]; then
  DO1=1; DO2=1; DO3=1; DO4=1;
fi

DOD=DRY
DOPFX=echo
if [[ $DO = 1 ]]; then DOD=DO; DOPFX=; fi
echo "This is $DOD run
  CMD $CMD
  xfer $SRC to $DEST
  STEP1 (KEEP SYSOLD): $DO1  STEP2(NOTHING): $DO2  STEP3(MAIN COPY): $DO3  STEP4(POST): $DO4,
  TWOPH $TWOF, BATCH $BANG, $DES
  SSH args $SARG
  SCP args $CSARG 
  RSYNC base args $BARG
  RSYNC step3 args $XARG
"


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
  #set -x
  ssh $SARG $SSH "set -e; echo \"* [\`date +%Y%m%d-%H%M\`][\`hostname -f\`] Preparing $DST sysold sysnew\"
    mkdir -p $DST/sysold
    mkdir -p $DST/sysnew
    rsync --version || { echo 'Rsync NOT found. Bye' && exit 2; }
    if [ -d $DST/sysold/etc ]; then echo \"Already existing $DST/sysold/etc. Bye\"; r=4; else $DOPFX cp -a $DST/etc $DST/sysold; fi
    if [ -d $DST/sysold/boot ]; then echo \"Already existing $DST/sysold/boot. Bye\"; r=5; else $DOPFX cp -a $DST/boot $DST/sysold; fi
    ke=\`uname -r\`
    echo \"RunningKernel \$ke\"
    mkdir -p $DST/sysold/lib/modules
    if [ -d $DST/sysold/lib/modules/\$ke ]; then echo \"Already existing $DST/sysold/lib/modules/\$ke. Bye\"; r=6; else $DOPFX cp -a $DST/lib/modules/\$ke $DST/sysold/lib/modules/\$ke; fi
    echo \"code \$r\";
    exit \$r"
  RT=$?; set +x
  [ "$RT" != "0" ] && ARET=$RT


  echo ""
  echo "*** STEP 1b: RSYNC $SRC/etc to $DEST/sysnew for reference"
  set -x
  rsync $BARG --delete --delete-before $SRC/etc/ $DEST/sysnew/etc/ -e "ssh $SARG"
  #scp -r $CSARG $SRC/etc/ $SSH:$DST/sysnew/etc/
  RT=$?;   set +x
  [ "$RT" != "0" ] && ARET=$RT
  #set -x
  #rsync $BARG --delete --delete-before $SRC/boot/ $DEST/sysnew/boot/ -e "ssh $SARG"
  ##scp -r $CSARG $SRC/etc/ $SSH:$DST/sysnew/etc/
  #RT=$?;   set +x
  #[ "$RT" != "0" ] && ARET=$RT

  if [[ $TWOF = 1 ]] ; then
    echo
    echo "*** STEP 1c (for two phase): RSYNC $SRC/bin sbin lib* to $DEST/sysnew for reference"
    rsync $BARG --delete --include='/bin*' --include='/sbin*' --include='/lib*' --exclude='/*' -e "ssh $SARG" $SRC/ $DEST/sysnew/
    RT=$?;   set +x
    [ "$RT" != "0" ] && ARET=$RT

    XARG="$XARG --exclude='/bin*' --exclude='/sbin*' --exclude='/lib*' "
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
fi

#if [[ $TWOF = 1 ]] && [[ $DO2 = 1 ]]; then
#  echo
#  echo "*** STEP 2 (for two phase): RSYNC $SRC/bin sbin lib* to $DEST/sysnew for reference"
#  rsync $BARG --delete --include '/bin*' --include '/sbin*' --include '/lib*' --exclude '/*' -e "ssh $SARG" $SRC $DEST/sysnew/
#  RT=$?;   set +x
#  [ "$RT" != "0" ] && ARET=$RT
#
#  XARG="$XARG --exclude '/bin*' --exclude '/sbin*' --exclude '/lib*' "
#fi

#if [ "$ARET" != "0" ];  then 
#  A=y
#  if [[ $BANG != 1 ]]; then
#    read -p "Maybe not or ?" A
#  fi
#  if ! [[ $A =~ y|Y ]]; then
#    exit 4
#  fi
#fi


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

  echo "*** STEP 3: RSYNC $SRC to $SSH:$DEST port $PORT, aHSKDz (all, hard links, sparse, keep dirlinks, dev & specials, zip)"

  if [[ $UN != 1 ]]; then
    echo "* SAFE mode, xclude also/etc/fstab  /etc/network/interfaces*, /etc/resolv.conf"
    ker=`ssh $SARG $SSH "uname -r"`
    RT=$?;   set +x
    [ "$RT" != "0" ] && ARET=$RT

    XARG="$XARG --exclude=/etc/fstab --exclude=\"/etc/network/interfaces*\" --exclude=/etc/resolv.conf  --exclude=\"/etc/sysconfig/network-scripts*\""
    if [ -n "$ker" ]; then
      echo "* Excluding running kernel $ker modules, boot stuff, keeping grub.conf"
      XARG="$XARG --exclude=\"/boot/*$ker*\" --exclude=\"/lib/modules/$ker\" --exclude=\"/usr/lib/modules/$ker\" --exclude=/boot/grub/grub.cfg"
    fi
  fi
  set -x
  CMD="rsync $BARG $XARG --exclude=/sys/ --exclude=/sysold --exclude=/sysnew --exclude=/proc/ --exclude=/dev/ --exclude=/tmp/ --exclude=\"/run/*\" --exclude=\"/var/run/*\" --exclude=/mnt/ --exclude=/media/ -e \"ssh $SARG\" $SRC/ $DEST/"
  eval $CMD
  RT=$?;   set +x
  [ "$RT" != "0" ] && ARET=$RT

  echo "*** SYNCED $ARET ***"
  if [[ $XARG =~ grub.cfg ]]; then
    # SAFE mode
    echo "*** We kept grub and kernel config. If you want to use new run 
cp -av /sysnew/boot/grub/grub.cfg /boot
"
  else
    ke=`uname -r`
    echo "** For keeping existing kernel do
cp -av /sysold/boot/vmlinuz-$ke /sysold/boot/initrd.img-$ke /boot/
cp -av /sysold/lib/modules/$ke /lib/modules/
    "
  fi


  if [[ $TWOF = 1 ]]; then
    echo "* Hopefully you already have a session and in addition to other tasks try to
- move back base utils (/bin /sbin/ lib*) from /sysnew to / (for stuff excluded)"
  fi

fi

if [[ $DO4 = 1 ]]; then
  echo
  echo "*** STEP 4: POST: fixings"

  echo "* POST: DIFFING"
  ssh $SARG -o StrictHostKeyChecking=no $SSH  "set -x; diff -u $DST/etc/fstab $DST/sysnew/etc/fstab; diff -u $DST/etc/network/interfaces $DST/sysnew/etc/network/interfaces; set +x;
   if [ \"$UN\" != \"1\" ]; then
     cp -av $DST/sysnew/etc/fstab $DST/etc/fstab.new
     cp -av $DST/sysnew/etc/network/interfaces $DST/etc/network/interfaces.new
     cp -av $DST/sysnew/etc/resolv.conf $DST/etc/resolv.conf.new
     echo '* Created /etc/fstab.new /etc/network/interfactes.new /etc/resolv.conf.new '
   fi
   chown root:root /
   chmod 755 /
   "
  RT=$?;   set +x
  [ "$RT" != "0" ] && ARET=$RT
  echo "CODE $RT"

  echo
  echo "*** Check. Maybe fix them manually !!:"
  echo "*
MAYBE KERNEL BOOT and initrd /boot/vmlinuz* /boot/initramfs*
MAYBE KERNEL MODULES /lib/modules/*
GRUB-INSTALL grub-install
DEVICES /etc/fstab
NETWORK /etc/network/interfaces* (debian) (then systemctl restart networking) or /etc/sysconfig/network-scripts* (rhel)
DNS /etc/resolv.conf
ACCESS check /etc/shadow and/or /root/.ssh/authorized_keys"
  if [[ $UN = 1 ]]; then
    echo "* This was an UNSAFE so things like fstab, boot, network were not exlcuded !!"
  fi
  ssh $SARG -o StrictHostKeyChecking=no $SSH  'hostname;
 ! [ -h /etc/mtab ] && cat /proc/mounts > /etc/mtab
 echo "* Fixing grub-install"
 root=`cat /proc/mounts  | awk '"'"' $2 ~ /^\/$/ { print $1; exit }'"'"' | sed '"'"'s/[0-9]*$//'"'"'`
 if [ -z "$root" ]; then root=/dev/sda; echo \"** Didnt find root device. Asuming $root\"; fi
 grub-install $root
 if grep debian /etc/os-release; then update-grub; fi
 set +x
 echo "* Fixing root passwd"
 if [ "'$BANG'" != "1" ]; then
   echo "Want to update root passwd? ";  read A
   if [ "$A" = "y" ]; then passwd root; fi
 else
   echo " Locking root pwd"
   passwd -l root
 fi
 echo "*** logout from `hostname -f`"'
  RT=$?;   set +x
  echo "CODE $RT"

fi


echo "CODE: $ARET"
