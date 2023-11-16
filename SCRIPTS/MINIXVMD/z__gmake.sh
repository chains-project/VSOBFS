#!bourne sh
# building gmake by Tiny C Compiler under Minix-vmd
#
# v.0.3 2023-03-05
# v.0.2 2023-03-01
# v.0.1 2023-02-26

set -e

set -x

tver="$1"; shift

# we will encounter files with names of exactly 14 bytes
# which can be the file system's limit, thus a workaround:
_fix()(
  fixfile="$1"; shift
# to avoid losing the original if doing multiple fixes
  [ -f "$fixfile"_ ] || cp "$fixfile" "$fixfile"_
#
  cp "$fixfile" "$fixfile". || return
  sed "$@" "$fixfile". >"$fixfile"
  diff -c "$fixfile". "$fixfile" || :
)
fix()(
  printf '%s\n' "==== fixing '$1'" >&2
  tst="$(basename "$1")"
  case "$tst" in
  ??????????????*)
    ffile="$1"; shift
    cp "$ffile" fix.tmp.file
    _fix fix.tmp.file "$@"
    mv fix.tmp.file "$ffile"
    rm fix.tmp.file?
    ;;
  *) _fix "$@" ;;
  esac
)
# do not ever try this on 14-byte long names:
#ffix(){
#  fix "$@"
#  rm -v "$1". "$1"_
#}

# the source archive is expected
# to be present in /mtop

# let us use hd2 as the work space

mkfs -t 2f /dev/hd2
mkdir -p /mnt
mount /dev/hd2 /mnt
cd /mnt
compress -d < /mtop/gmake.TAZ | tar xf -
# free disk space
rm /mtop/gmake.TAZ

# it is a certain gmake version which we handle
cd /mnt/make-"$tver"

# gmake checks the current time and compares
# to the modification time of the source,
# complains if time goes backward, work around:
find . -type f | xargs touch
# ensure that time has become later
sleep 1

# ==============================================
# Minix-specific gmake adjustments:
# (note, this gmake version is compilable by ack,
# but let us use Tiny C for a change)

fix read.c '
/extern.char.\*getlogin/,/}/c\
home_dir = 0;
'
fix glob/glob.c '
/^#   if defined HAVE_GETLOGIN_R || defined _LIBC/,/^#   endif/c\
             success = 0;
'
fix main.c '
/^main (argc, argv, envp)/,/^{$/c\
main (argc, argv)\
     int argc;\
     char **argv;\
{\
  char **envp = environ;\
#endif
'
needed_for_ack(){
# a preprocessor quirk
fix gettext.h '
/^#if !HAVE_LC_MESSAGES/c\
#ifndef HAVE_LC_MESSAGES
'
}
# END needed_for_ack()

# a plain miss
fix gettext.c '
/#define _GETTEXT_H 1/a\
\
#ifndef LC_MESSAGES\
# define LC_MESSAGES (-1)\
#endif
'

# this is wrong, fix:
fix main.c '
/if defined(MAKE_JOBSERVER) && defined(HAVE_FCNTL_H)/s|.*|#if defined(HAVE_FCNTL_H)|
'
fix getloadavg.c '
/include <sys\/param\.h>/s|.*|/* & */|
'

fix make.h '
/uintmax_t/s||long long|
'

# NOTE with ack do not use -O2, it will miscompile
CC='tcc -DNO_GET_LOAD_AVG' \
LD=tcc \
AR='tcc -ar' \
RANLIB=: \
CFLAGS="-I/usr/include/bsdcompat -D_POSIX_SOURCE -O" \
sh configure \
 --host=i486-pc-minix \
 --build=i486-pc-minix \
 --target=i486-pc-minix \
 --prefix=/opt/gnu \


# configure does not do its very job properly ...
fix config.h '
/#define.*_t/s|.*|/* & */|
/HAVE_SYS_WAIT_H/s|.*|#define HAVE_SYS_WAIT_H 1|
'

sh -x build.sh

# use the new make to continue
./make install

# do full bootstrap
PATH=/opt/gnu/bin:"$PATH"; export PATH

make clean
make
ls -l make /opt/gnu/bin/make
make install
ls -l make /opt/gnu/bin/make
make clean
make
ls -l make /opt/gnu/bin/make
( set -x; cmp make /opt/gnu/bin/make ) &&
  printf '%s\n' "the new make is identical to the previous build pass" ||
  exit 1
ln /opt/gnu/bin/make /opt/gnu/bin/gmake
ls -li /opt/gnu/bin/*make

cd /
umount /dev/hd2

exit
