#!bourne sh
# building gmake by Tiny C Compiler under Minix-2
#
# v.0.3 2023-03-04
# v.0.2 2023-03-01
# v.0.1 2023-02-26

set -e

set -x

tver="$1"; shift

# we will encounter files with names of exactly 14 bytes
# which is the file system's limit, thus a workaround:
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

# let us use c0d0p1 as the work space

mkfs /dev/c0d0p1
mkdir -p /mnt
mount /dev/c0d0p1 /mnt
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

# missing in Minix-2, let's borrow from Minix-vmd :
cat >ar.h <<'____'
#ifndef _AR_H_
#define _AR_H_

#include <ansi.h>

/* Pre-4BSD archives had these magic numbers in them. */
#define OARMAG1 0177555
#define OARMAG2 0177545

#define ARMAG           "!<arch>\n"     /* ar "magic number" */
#define SARMAG          8               /* strlen(ARMAG); */

#define AR_EFMT1        "#1/"           /* extended format #1 */

struct ar_hdr {
        char ar_name[16];               /* name */
        char ar_date[12];               /* modification time */
        char ar_uid[6];                 /* user id */
        char ar_gid[6];                 /* group id */
        char ar_mode[8];                /* octal file permissions */
        char ar_size[10];               /* size in bytes */
#define ARFMAG  "`\n"
        char ar_fmag[2];                /* consistency check */
};

#endif /* !_AR_H_ */
____
fix arscan.c '
/<ar\.h>/s||"ar.h"|
'
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

# set about double of what it was:
chmem =90000 /bin/sh

# these were for ack:
# CC='cc -Duintmax_t=long -DNO_GET_LOAD_AVG -DHAVE_VPRINTF -DHAVE_STRERROR' \
# LD=cc \
# AR=aal \
# CFLAGS="-DNO_ARCHIVES -D_POSIX_SOURCE -O" \
# NOTE with ack do not use -O2, it will miscompile

# these were for tinycc:
# CC='/opt/tinycc/bin/tcc -DNO_GET_LOAD_AVG' \
# LD=/opt/tinycc/bin/tcc \
# AR='/opt/tinycc/bin/tcc -ar' \
# CFLAGS="-D__WCHAR_TYPE__=char -D_POSIX_SOURCE -O" \

CC='/opt/tinycc/bin/tcc -DNO_GET_LOAD_AVG' \
LD=/opt/tinycc/bin/tcc \
AR='/opt/tinycc/bin/tcc -ar' \
RANLIB=: \
CFLAGS="-D__WCHAR_TYPE__=char -D_POSIX_SOURCE -O" \
sh configure \
 --host=i486-pc-minix \
 --build=i486-pc-minix \
 --target=i486-pc-minix \
 --prefix=/opt/gnu \


# configure does not do its very job properly ...
# this was needed too, for ack:
# /#define.*_t/s|.*|/* & */|
fix config.h '
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
umount /dev/c0d0p1

exit
