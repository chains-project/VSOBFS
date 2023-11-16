#!bourne sh
#
# last changed 2023-03-05 an
#
# this script is to be sourced at the beginning of every z_?*.sh script
# and also at the beginning of every [abc...]_*.sh script as
#  . "$A"/SCRIPTS/MINIX204/z_.sh

die(){
  printf '%s\n' " $*
 -- aborting" >&2
  exit 1
}

usage(){
  die "\
environment variables A and B must be set to existing absolute paths,
see the top-level README.txt"
}

case "$A" in
(/*) case "$B" in (/*) ;; (*) usage ;; esac ;;
(*) usage ;;
esac
[ -d "$A" ] && [ -d "$B" ] || usage
cd "$B" || usage
umask 022

# this file tree is to be prepared by the cross-compiler compilation scripts:
top="$B"/top

case "$PATH" in
("$top"/bin:*|*:"$top"/bin:*) ;;
(*) PATH="$top"/bin:"$PATH" ;;
esac

mkdir -p "$top"
mkdir -p "$top"/bin

ACKDESCR="$top"/lib/descr
export ACKDESCR

# this is the place to put the built target platform's binaries
# and their data into:

mtop="$B"/mtop
mkdir -p \
      "$mtop" \
      "$mtop"/bin \
      "$mtop"/include \
      "$mtop"/lib \
      "$mtop"/lib/ego \
      "$mtop"/lib/i386 \
      "$mtop"/lib/i86 \
      "$mtop"/usr \
      "$mtop"/usr/bin \
      "$mtop"/usr/lib \


# NOTE1 not all potential build platforms support "diff -u",
# that's why we are using "diff -c"
# NOTE2 some potential platforms have file length limitations
# and may allow for max 14 bytes in a file name,
# that's why we use a short renaming pattern, to reduce
# the chance of name truncation; the suffix (i.e. not a prefix)
# provides the resistance against accidentally matching patterns
# of *.h *.c and alike
fix(){
  fixfile="$1"; shift
  printf '%s\n' "==== fixing '$fixfile'" >&2
# to avoid losing the original if doing multiple fixes
  [ -f "$fixfile"_ ] || cp "$fixfile" "$fixfile"_
#
  cp "$fixfile" "$fixfile". || return
  sed "$@" "$fixfile". >"$fixfile"
  diff -c "$fixfile". "$fixfile" || :
}

