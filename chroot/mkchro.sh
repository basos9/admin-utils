#!/bin/bash
# Create chroot directory


DIR=$1
USER=$2
XTRA=$3
BASE=$(readlink -f $DIR)

usage()
{
  echo "$0 <dir> [<user>] [\"dproc\"]
  Create basic chroot to directory dir:
  Copy only busybox, no libraries
  Optionally setup home for user user
  When dproc also create dev,proc,sys.
"
}
if [ -z "$DIR" ] || ! [ -d $DIR ]; then
    echo "Dir $DIR not found" >&2
    usage
    exit 4
fi
if [ -n "$USER" ] || ! groups $USER; then
   echo "User $USER not found " >&2
   usage
   exit 5
fi

set -e
cd $DIR
echo "* Creating chroot on $BASE for user $USER"

if [[ $XTRA =~ dproc ]]; then
  echo "* Mounting directories dev,dev/pts,proc,sys"
  mkdir -p dev
  mount | grep "$BASE/dev " ||
    mount -o bind /dev dev
  mount | grep "$BASE/dev/pts " ||
    mount -t devpts pts dev/pts
  mkdir -p proc
  mount | grep "$BASE/proc " ||
    mount -t proc proc proc
  mkdir -p sys
  mount | grep "$BASE/sys " ||
    mount -t sysfs sys sys

else
   echo "* Simple dev"
   mkdir -p dev
   cp -av /dev/stdin /dev/stdout /dev/stderr /dev/zero /dev/null dev
fi


#echo "* Copy lib preloader"
#mkdir -p lib64
#cp -av /lib64/ld-linux-x86-64.so.2 lib64

echo "* Basic /etc"
mkdir -p etc
echo > etc/passwd


echo "* Copy binaries"
mkdir -p bin
cp -av /bin/busybox bin/busybox
ln -sTf busybox bin/sh
ln -sTf busybox bin/cat

if [ -n "$USER" ]; then
  echo "* Home directory for $USER"
  mkdir -p home
  mkdir -p home/$USER
  chown $USER:$USER home/$USER
  grep "^$USER:" /etc/passwd >> etc/passwd
fi


chroot . /bin/sh -c 'echo "Seems OK, `whoami` @ `hostname`: "`ls bin`'
echo "* Done"

