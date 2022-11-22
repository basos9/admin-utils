#!/bin/bash

BASE=$(readlink -f `dirname $0`)
STAMP=`date +%Y%m%d-%H%M`
LOCK=/tmp/`basename $0`back.lock

techo()
{
  echo "[`date +%Y%m%d-%H%M`][`hostname -f`][`basename $0`] $@"
}

usage()
{
  cat >&2 <<EOF
Usage: $0 <ssh> <outd> 
  Virtualmin backup and tar, then send to remote ssh
   ssh: <[user@]hostname or ssh://[user@]hostname[:port]>
   outd: remote directory, attempt to be created
   -k <keeplast>, keep this number of backups, default keep all
   -s, use sh mode for -k, also needs grep and ls, use in busybox chroots
   -V skip virtualmin backup, use contents of /var/backups/virtualmin
EOF

}

SH=
DOV=1
SSHOPTS=
KEEPLAST=
while getopts "hk:Vs" OPTION
do
     case $OPTION in
         h)  usage; exit 1 ;;
	 k)  KEEPLAST=$OPTARG; ! [[ $KEEPLAST -ge 0 ]] && techo "Invalid arg -k" >&2 ;;
         V)  DOV=0 ;;
         s)  SH=1 ;;
         ?)  usage; exit ;;
     esac
done
shift $(( $OPTIND - 1 ))

SSH="$1"
OUTD="$2"
#shift 1

if [ -z "$SSH" ] || [ -z "$OUTD" ]; then
  usage
  exit 4
fi

set -o pipefail


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

BACKNAME=$(date +%Y%m%d-%H%M)

  if [ "$HOSTK" = "1" ]; then
    SSHOPTS="${SSHOPTS}${SSHOPTS:+ }-oStrictHostKeyChecking=accept-new"
  fi
  if [ "$PASSAUTH" != "1" ]; then
    SSHOPTS="${SSHOPTS}${SSHOPTS:+ }-oPasswordAuthentication=no"
  fi
  #set -x
  ssh $SSHOPTS $SSH "[ -d '$OUTD' ] || { echo \"[\`hostname -f\`] Creating dir $OUTD\" && mkdir -p $OUTD ; }"; r=$?
  set +x
  if [ $r == 255 ]; then
    techo "[*] Maybe ssh public key not registered for $SSH. Dumping key." >&2
    set -x
    cat ~/.ssh/id_rsa.pub >&2
    set +x
  fi
  if [ "$r" != "0" ]; then
    techo "[*] ERROR creating remote dir" >&2
    exit 3
  fi
  if [ "$DOV" = "1" ]; then
  techo "[+] Taking virtmin backup local @ `hostname -f`";
  set -x
  virtualmin backup-domain --dest /var/backups/virtualmin/ --newformat --compression bzip2 --all-features --ignore-errors --all-domains; r=$?; 
  set +x
  if [ "$r" != "0" ]; then
    techo "[*] ERROR taking virtualmin local backup. CODE: $r. Bye" >&2
    exit 4
  fi
  fi
  techo "[*] Syncing back to source revese channel at '$PORT'";
  set -x
  tar -cf - /var/backups/virtualmin | ssh $SSHOPTS $SSH "cat > $OUTD/$BACKNAME.tar.wip && mv $OUTD/$BACKNAME.tar.wip $OUTD/$BACKNAME.tar"; r=$?
  set +x
  if [ "$r" != "0" ]; then
    techo "[*] ERROR taring & sshing. CODE $r. Bye" >&2
    exit 4
  fi

  if [[ $r == 0 ]] && [ -n "$KEEPLAST" ] && [ $KEEPLAST -ge 0 ]; then
    if ! [[ $SH = 1 ]]; then
      ssh $SSH $SSHOPTS 'kf='$KEEPLAST'
    cd '$OUTD' || exit 4
    echo "[`hostname -f`][+] Keeping latest $kf files *.*r, BASH, sorted by moddate"
    declare -a a
    a=(`ls -1t -p *r | grep -v /$`)
    echo "[++] ALL FILES ${#a[@]} ::: ${a[@]}";
    for i in `seq $kf $((${#a[@]}-1))`; do f=${a[$i]}; rm -fv "$f" ; done
    '
    else
      ssh $SSH $SSHOPTS 'kf='$KEEPLAST'
    set -e
    cd '$OUTD' || exit 4
    echo "[+] Keeping latest $kf files *.*r, SH/GREP/LS sorted by moddate"
    a=`ls -1t -p *r | grep -v /$`
    echo "[++] ALL FILES ${a}";
    n=0
    for f in ${a}; do n=$(($n+1)); done
    i=0
    for f in ${a}; do if [ $i -ge $kf ] && [ $i -lt $n ]; then rm -fv "$f" ; fi; i=$(($i+1)); done
    '
    fi
    r=$?
  fi

if [ "$r" != "0" ]; then 
  techo "[*] FAILED (code $r) " >&2; exit $r;
else
  techo "[+] SUCCESS (code $r) " >&2
fi
