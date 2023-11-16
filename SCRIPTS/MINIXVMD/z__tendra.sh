#!bourne sh
# building TenDRA C/C++ compiler under i386 Minix-vmd
#
# v.0.7 2023-03-01
# v.0.6 2023-02-23
# v.0.5 2023-02-15
# v.0.4 2023-02-14
# v.0.3 2023-02-12
# v.0.2 2023-02-05
# v.0.1 2022-09-25

set -e

tver="$1"; shift
ttver=4.1.2
tnam=TenDRA
ttnam="$tnam"

# we might encounter files with names of exactly 14 bytes
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
# (below we have a use case, without breakage)
ffix(){
  fix "$@"
  rm -v "$1". "$1"_
}

mkfs -t 2f /dev/hd2
mkdir /mnt
mount /dev/hd2 /mnt
cd /mnt

# ======================================================
# first build Minix-2 libraries etc, to provide
# the expected environment for the TenDRA build routines
compress -d < /mtop/SYS.TAZ | tar xf - \
                              include \
                              src/lib \
                              src/fs \
                              || :
rm -f /mtop/SYS.TAZ

mkdir -p /opt/mnx2
mv include /opt/mnx2

cd src/lib
mkdir -p /opt/mnx2/lib/ack
# do not build for languages other than C, nor for i86
fix Makefile '
/\$(LIB.*)\/libm2\.a:/,/^$/d
/\$(LIB.*)\/libp\.a:/,/^$/d
/libm2/d
/libp/d

/^LIB=/s|/usr.*|/not_to_exist/i86|
/^LIB386=/s|/usr.*|/opt/mnx2/lib/ack/i386|
/^LIB86=/s|/usr.*|/not_to_exist/i86|
/`arch`/s||$(ARCH)|

/xargs rm/s||while read a; do rm "$$a"; done|
'
fix posix/Makefile '
/\/usr/s|/usr.*||
'

for a in /usr/lib/ack/* ; do
  ( set -x; ln -s "$a" /opt/mnx2/lib/ack )
done
( set -x; rm -f /opt/mnx2/lib/ack/descr )
( set -x; rm -f /opt/mnx2/lib/ack/i386 )
( set -x; rm -f /opt/mnx2/lib/ack/i86 )

( set -x; mkdir /opt/mnx2/lib/ack/i386 )
for a in as cg ; do
  ( set -x; ln -s /usr/lib/ack/i386/"$a" /opt/mnx2/lib/ack/i386 )
done

# instruct cc to use the Minix-2 includes
# and the corresponding newly built libraries

# --- build as for Minix-2 :
# NOTE we remove the definition of __minix_vmd, otherwise
# this triggers looking for different include files
# note also the library additions needed to use ack/Minix-2 floating point
  sed '
/^AAL =/s|/.*|'"$top"/bin/aal'|
/AAL cr/s||AAL Dcr|
/^CPP_F =/s| -D__minix_vmd||
/^ACK_CPP =/s|$| -I/opt/mnx2/include|
/^ACK_CEM =/s|CPP_F|& -I/opt/mnx2/include|
/^L =/s|=.*|= '/opt/mnx2/lib'|
/^if \$PREF_BE = ack/,/^$/{
  /libs =/s|$| $A/$ARCH/libe.a $A/$ARCH/libfp.a|
}
/import ARCH/a\
\
MNX_ARCH = i386
  ' /usr/lib/ack/descr > /opt/mnx2/lib/ack/descr
echo ================================
diff -c /usr/lib/ack/descr /opt/mnx2/lib/ack/descr || :

ACKDESCR=/opt/mnx2/lib/ack/descr; export ACKDESCR

ARCH=i386 make clean
ARCH=i386 make install

# ======================================================
# now we can proceed with TenDRA

doweneedthis(){
# for Tiny C Compiler we will need to initialize the FPU;
# besides this something like the following should (?) have been done
# in privileged mode by the kernel:
#        .data1  0x0F,0x20,0xC0          ! mov   %eax, %cr0
#        and     %ax, $65531             ! 65535-4==0xfffb, clear bit EM (2^2=4) to indicate presence of FPU
#        or      %ax, $32                ! 32==0x20, set bit NE (2^5=32) to turn off MSDOS compat mode
#        .data1  0x0F,0x22,0xC0          ! mov   %cr0, %eax
fix /mnt/src/lib/i386/rts/crtso.s '
/call.*_main/i\
\        .data1  0xDB,0xE3               ! fninit
'
}

cd /mnt

# TenDRA build uses "ar" which on Minix-vmd is no longer aal,
# we have to insist on getting aal as ar
mkdir bin
ln -s /usr/bin/aal bin/ar
PATH=/mnt/bin:"$PATH"

compress -d < /mtop/"$tnam""$tver".TAZ | tar xf -
rm /mtop/"$tnam""$tver".TAZ
cd "$ttnam"-"$ttver"

mkdir -p /opt/tendra/bin \
         /opt/tendra/lib \
         /opt/tendra/man

fix INSTALL '
/^BASE_DIR=/s|=.*|=/mnt/'"$ttnam"'-'"$ttver"'|
/^PUBLIC_BIN=/s|=.*|=/opt/tendra/bin|
/^INSTALL_DIR=/s|=.*|=/opt/tendra/lib|
/^MAN_DIR=/s|=.*|=/opt/tendra/man|
/^TEMP_DIR=/s|=.*|=/tmp|
/^SYS_INCLUDES=/s|=.*|="-I/opt/mnx2/include"|
'

# the paths are different
# (and at least on Minix-2 more memory is needed than anticipated)
fix src/build/minix.opt '
/chmem =196608  \/usr\/lib\/em_led/s|196608|538122|
/chmem =163840  \/usr\/bin\/make/a\
\         chmem =337920  /usr/lib/em_opt     # 330K
/\/usr\/lib/s||/opt/mnx2/lib/ack|
'
for a in \
src/lib/env/minix/aout/80x86/default.extra \
src/lib/machines/minix/80x86/src/Makefile \
src/lib/machines/minix/80x86/src/c/Makefile \
src/lib/machines/minix/80x86/src/ld \
src/utilities/make_mf/*.ini \
; do
  fix "$a" '
/\/usr\/lib/s||/opt/mnx2/lib/ack|g
/\/usr\/local\/bin\/ld/s||/opt/tendra/bin/ld|
  '
done
for a in $(find . | xargs grep -l /usr/bin/ash) ; do
  fix "$a" '
/\/usr\/bin\/ash/s||/bin/sh|
  '
done
for a in $(find . | xargs grep -l /usr/src) ; do
  fix "$a" '
/\/usr\/src/s||/mnt/src|g
  '
done
for a in \
src/build/minix.opt \
src/lib/env/common/system \
src/lib/env/common/system+ \
src/lib/machines/minix/80x86/src/c/posix.mak \
src/tools/tspec/makefile.c \
; do
  fix "$a" '
/\/usr\/include/s||/opt/mnx2/include|g
  '
done
for a in \
src/utilities/make_mf/check.ini \
src/utilities/make_mf/compile.ini \
src/utilities/make_mf/make_mf.ini \
; do
  fix "$a" '
/\/usr\/include/s||/opt/mnx2/include|
/^+L/{
  /\/mnx2/!d
}
  '
done

# turn on support for a 64-bit-type
cat src/lib/env/common/longlong >> src/lib/env/common/building
for a in \
src/lib/startup/Bounds.ansi/default.pf \
src/lib/startup/Bounds.32/default.pf \
; do
  ffix "$a" '
/long_bits/a\
longlong_bits                   64
  '
done

# make it reproducible (!)
# fixing of unreasonably embedded paths of compile-time files:
fix src/utilities/make_mf/main.c '
/^#ifndef INIT_FILE/i\
#undef INIT_FILE
'
fix src/tools/tspec/name.h '
/^#ifndef INPUT_DIR/i\
#undef INPUT_DIR
/^#ifndef INCLUDE_DIR/i\
#undef INCLUDE_DIR
/^#ifndef SRC_DIR/i\
#undef SRC_DIR
'

# then follows embedding of a timestamp (for generation of "globally unique" names?),
# not really a good approach, replace it by an arbitrarily chosen constant :)
fix src/installers/80x86/minix/install_fns.c '
/t = time(NULL) + (time_t)(seq_n++);/s|time(NULL)|(time_t)'12345'|
'

# also let the archiver make reproducible archives
for a in \
src/lib/libtdf/Makefile \
src/lib/cpp/src/Makefile \
; do
  fix "$a" '
/\${AR} cr/s||${AR} Dcr|
  '
done

### a bit of brain surgery to avoid the influence of memory allocation
### on reproducibility (otherwise labels are generated from structure
### addresses in the compiler memory - a clever hack, but an inappropriate one)
###
### NOTE WARNING BEWARE it looks like making the exp_t structure larger
### results in the allocation unit in construct/exp.c changing
### from below 512K to above 512K - for that or some other reason
### on Minix-2 (not on e.g. Linux) the resulting compiler binaries become
### flaky and behave badly, our workaround is to put the necessary new field
### into the available unused bits in the structure
### (tested: reducing current_alloc_size in construct/exp.c makes
### it work even with a bigger struct exp_t, but using the available bits
### is the best approach anyway)
fix src/installers/80x86/common/exptypes.h '
/park : 1;/a\
\    unsigned int stable_ref : 30; /* for reproducible generation of labels */
'
fix src/installers/80x86/minix/instr.c '
/l\.i/s||l.e->stable_ref|
'
fix src/installers/common/construct/exp.c '
/if (freelist != nilexp)/i\
\  static long stable_ref_gen = 0;
/freelist = son/a\
\      res->stable_ref = ++stable_ref_gen;
/res = next_exp_ptr/a\
\  res->stable_ref = ++stable_ref_gen;
'

# diagnostics (aka debug?) is not usable, according to README.minix,
# and creates non-reproducible libraries, disable the rest of it 
fix INSTALL '
/for LIBDIR in lib lib\/diag/s||for LIBDIR in lib|
'

# can we expect a meaningful return status from ./INSTALL ? no
./INSTALL

cd /
umount /dev/hd2

# show that the compiler actually works
cat >/root/thelloworld.c <<'____'
#include <stdio.h>
int main(int argc, char **argv){
  printf("hello from TenDRA\n");
  return 0;
}
____

PATH=/opt/tendra/bin:"$PATH"
( set -x
  tcc -Ysystem -O -s -o /root/thelloworld /root/thelloworld.c
  /root/thelloworld
)

exit
