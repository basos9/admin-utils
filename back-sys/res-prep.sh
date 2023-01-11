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
   -d <pass-option> decrypt with openssl enc, argument is -pass argument of openssl enc or "ask" or "-" for interactive

EOF
 }

 ENCR=
 ENCR_PARG=
 ENCR_ARG="-pbkdf2 -aes256 -d"
 while getopts “hd:” OPTION
 do
 case $OPTION in
   h)  usage; exit 1 ;;
   d)
     ENCR="openssl enc" ; [[ $OPTARG != "ask" ]] && [[ $OPTARG != "-" ]] && ENCR_PARG="-pass $OPTARG" ;;
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

techo "[+] Prepargin file $SRC for outdir (mountpoint) $OUTD, Enc: $ENCR"

if [ -n "$ENCR" ]; then
  SRC1=${SRC//.cr}
  if [ "$SRC" = "$SRC1" ]; then
     SRC1="${SRC}.dec"
  fi
  techo "[+] Decrypting to $SRC1"
  $ENCR < $SRC > $SRC1
  r=$?

  if [ "$r" != "0" ]; then
     techo "[+] Error decrypting ($r). Exiting" >&2
     exit $r
  fi
fi

# use parallel processors for bzip2
ratarmount  -o ro -P 4 "$SRC1" $OUTD
r=$?

if [ "$r" != "0" ]; then
  techo "[*] FAILED (code $r) " >&2; exit $r;
else
  techo "[+] SUCCESS (code $r). Output to $OUTD" >&2
fi
