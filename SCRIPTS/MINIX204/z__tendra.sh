#!bourne sh
# building TenDRA C/C++ compiler under i386 Minix
#
# v.0.4 2023-02-14
# v.0.3 2023-02-12
# v.0.2 2023-02-05
# v.0.1 2022-09-25

set -e

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
ffix(){
  fix "$@"
  rm -v "$1". "$1"_
}

# TenDRA expects the library sources to be present for perusal
# and on Minix-2 we can not get away with a symlink,
# put the data in place, for the moment
( cd /usr; compress -d < /mtop/SYS.TAZ | tar xf - src || : )

rm -f /mtop/SYS.TAZ

# for Tiny C Compiler we will need to initialize the FPU;
# besides this something like the following should (?) have been done
# in privileged mode by the kernel:
#        .data1  0x0F,0x20,0xC0          ! mov   %eax, %cr0
#        and     %ax, $65531             ! 65535-4==0xfffb, clear bit EM (2^2=4) to indicate presence of FPU
#        or      %ax, $32                ! 32==0x20, set bit NE (2^5=32) to turn off MSDOS compat mode
#        .data1  0x0F,0x22,0xC0          ! mov   %cr0, %eax
fix /usr/src/lib/i386/rts/crtso.s '
/call.*_main/i\
\        .data1  0xDB,0xE3               ! fninit
'

mkfs /dev/c0d0p1
mkdir /mnt
mount /dev/c0d0p1 /mnt
cd /mnt
compress -d < /mtop/TenDRA412b.TAZ | tar xf -
rm /mtop/TenDRA412b.TAZ
cd TenDRA-4.1.2/

mkdir -p /opt/tendra/bin \
         /opt/tendra/lib \
         /opt/tendra/man

fix INSTALL '
/^BASE_DIR=/s|=.*|=/mnt/TenDRA-4.1.2|
/^PUBLIC_BIN=/s|=.*|=/opt/tendra/bin|
/^INSTALL_DIR=/s|=.*|=/opt/tendra/lib|
/^MAN_DIR=/s|=.*|=/opt/tendra/man|
/^TEMP_DIR=/s|=.*|=/tmp|
'
# more memory is needed than anticipated
fix src/build/minix.opt '
/chmem =196608  \/usr\/lib\/em_led/s|196608|538122|
/chmem =163840  \/usr\/bin\/make/a\
\         chmem =337920  /usr/lib/em_opt     # 330K
'
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

# clean up /usr/src
rm -rf /usr/src

cd /
umount /dev/c0d0p1

# this TenDRA installation relies on the absolute path /usr/local/bin/ld
mkdir -p /usr/local/bin
for a in /opt/tendra/bin/* ; do
  ln "$a" /usr/local/bin
done

# show that the compiler actually works
cat >/root/thelloworld.c <<'____'
#include <stdio.h>
int main(int argc, char **argv){
  printf("hello from TenDRA\n");
  return 0;
}
____

PATH=/usr/local/bin:"$PATH"
( set -x
  tcc -Ysystem -O -s -o /root/thelloworld /root/thelloworld.c
  /root/thelloworld
)

exit
