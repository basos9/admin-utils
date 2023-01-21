#!/bin/bash
#


techo()
{
    echo "[`date +%Y%m%d-%H%M`][`hostname -f`][`basename $0`] $@"
}

usage()
{
 cat >&2 <<EOF
  Usage: $0 [opt] <SRCFILE> <OUTD>
   -d <pass-option> decrypt with openssl enc, argument is -pass argument of openssl enc or "ask" or "-" for interactive. Useful options are env:<var>, file:<path>
   -k Do not unlink decrupted file

EOF
 }

 ENCR=
 ENCR_PARG=
 ENCR_ARG="-pbkdf2 -aes256 -d"
 RMDEC=1
 while getopts “hd:k” OPTION
 do
 case $OPTION in
   h)  usage; exit 1 ;;
   d)
     ENCR="openssl enc" ; [[ $OPTARG != "ask" ]] && [[ $OPTARG != "-" ]] && ENCR_PARG="-pass $OPTARG" ;;
   k)
     RMDEC=0 ;;
   ?)  usage; exit ;;
  esac
done
shift $(( $OPTIND - 1 ))
set -o pipefail

SRC="$1"
shift 1
[ -z "$SRC" ] && usage && exit 4
OUTD="$1"
shift 1
[ -z "$OUTD" ] && usage && exit 4


SRC1=$SRC

if [ -n "$ENCR" ]; then
  ENCR="$ENCR $ENCR_ARG $ENCR_PARG"
fi

MP=$OUTD

techo "[+] Preparing file $SRC for outdir (mountpoint) $OUTD, Enc: $ENCR, UNLINKDEC: $RMDEC"

if [ -n "$ENCR" ]; then
  SRC1=${SRC//.cr}
  if [ "$SRC" = "$SRC1" ]; then
     SRC1="${SRC}.dec"
  fi
  SRC1="$OUTD/`basename $SRC1`"
  techo "[+] Decrypting to $SRC1"
  $ENCR < $SRC > $SRC1
  r=$?

  if [ "$r" != "0" ]; then
     techo "[+] Error decrypting ($r). Exiting" >&2
     exit $r
  fi
  MP="$OUTD/mp"
fi

RATARMOUNT=ratarmount

if ! which $RATARMOUNT; then
  RATARMOUNT=$HOME/.local/bin/ratarmount
fi

# use parallel processors for bzip2
$RATARMOUNT  -o ro -P 4 "$SRC1" $MP
r=$?


if [ -n "$ENCR" ] && [ "$RMDEC" = "1" ] ; then
  echo "Unlinking decrypted"
  rm -f $SRC1
fi

if [ "$r" != "0" ]; then
  techo "[*] FAILED (code $r) " >&2; exit $r;
else
  techo "[+] SUCCESS (code $r). Output to $MP" >&2
fi
