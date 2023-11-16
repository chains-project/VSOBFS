#!bourne sh
# rebuilding ackpack under i386 Minix
#
# uses:
#   @---LASTBL---@
#
# v.0.7 2023-02-13
# v.0.6 2023-02-11
# v.0.5 2023-02-05
# v.0.4 2022-09-24
# v.0.3 2022-08-11

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

___BUILD_ACK(){

cd /mtop
rm -rf ackpack
compress -d <SOURCES/ackpack.TAZ | tar xf -
cd ackpack

# we are run two times, during the second run
# it is the compiler from /usr/bin which is being used,
# the stack adjustments to the binaries in /mtop/bin
# will be irrelevant and a no-op anyway,
# "install" then is going to replace the used binaries
# in-place, which should be ok

# applying fixes from cross compilation,
# as long as they lead to some improvement

############## make this compiler more suitable for reproducible builds
############## (render __DATE__, __TIME__, __FILE__ harmless)
for a in \
lang/cem/cpp/init.c \
lang/cem/comp/init.c \
; do
  fix "$a" '
/[^l]time(&clock);/c\
\        clock = 0;
  '
done
for a in \
lang/cem/cpp/replace.c \
lang/cem/comp/replace.c \
; do
  fix "$a" '
/strcpy(&FilNamBuf\[1], FileName);/c\
\                {\
\                  char *p;\
\                  if ((p=strrchr(FileName,'"'"'/'"'"'))) ++p;\
\                  else p = FileName;\
\                  strcpy(&FilNamBuf[1], p);\
\                }
  '
done

### fix a bug where the code tries to free a static string
fix lang/cem/comp/input.c '
/return "\.";/s|"\."|Salloc(&, 2)|
'

### fix a "suspected" bug
patch -p1 < ../SOURCES/patch.suspected.comparebug

# imitate "make pepare-ack", but with relevant paths
# -------------------------
p() {
  chmod u+w $1
  mem=`chmem +0 $1 | sed -e 's/.*to \([0-9]*\).*/\1/'`
  if [ $mem -lt $2 ]
  then
    echo "*** Increasing memory allocated to $1"
    chmem =$2 $1
  fi
}

p /mtop/lib/cv 600000
p /mtop/lib/em_cemcom.ansi 600000

# Values below allow self compilation of ACK with -O2
p /mtop/lib/ego/bo 786432
p /mtop/lib/ego/ca 786432
p /mtop/lib/ego/cf 786432
p /mtop/lib/ego/cj 786432
p /mtop/lib/ego/ic 1179648
p /mtop/lib/ego/sp 786432
# -------------------------

# we do not want "undefined reference to `ASSERT'" ...
fix lang/cem/comp/ival.g '
/ASSERT/s||LL_assert|
'

# let ar be aal and also create easily verifiable libraries
for a in \
make/Make.ego \
make/Make.em \
make/Make.libbas \
make/Make.libocm \
make/Make.mod \
; do
  fix "$a" '
/ar cr/s||aal Dcr|
  '
done

# we do not need the other languages' front-ends
fix Makefile '
/\$l\/em_basic \\$/,/\$l\/i386\/libbas\.a \$l\/em_m2/d
/\$l\/em_pc \$l\/em_led/s||$l/em_led|
'

make

# do not try to install the parts which we did not build
fix Makefile '
/^install:/,/^$/{
  /if \[ -f make\/Make\.basic ] ; then/,/for m in/{
    /for m in/!d
  }
}
'

mkdir -p \
      /usr \
      /usr/bin \
      /usr/include \
      /usr/lib \
      /usr/lib/ego \
      /usr/lib/i386 \
      /usr/lib/i86 \
      /usr/man \
      /usr/man/man1 \
      /usr/man/man5 \
      /usr/man/man6 \


make install

cp /mtop/lib/ego/i386descr \
   /mtop/lib/ego/i86descr \
                          /usr/lib/ego

fix /usr/lib/descr '
/^L =/s|/.*|/lib /usr/lib|
/^AAL =/s|/.*|/usr/bin/aal|
/^CPP_F =/s| -I/mtop/include||
  '
}
# end of ___BUILD_ACK()

# run 1: build a new compiler in the "usual" file trees,
# using the one in /mtop
___BUILD_ACK

# ---------- we have got a new compiler

# ensure that we do not carry on ACKDESCR (it should be harmless anyway)
# nor run any of the earlier cross-built binaries (except /bin/sh)
unset ACKDESCR
PATH=/bin:/usr/bin:/sbin:/usr/sbin
export PATH

# ---------- build the libraries
cd /mtop
# tar complains about missing hardlink targets... ok
compress -d < SOURCES/SYS.TAZ | tar xvf - \
                                src/lib \
                                src/fs \
                                || :

cd src/lib
mkdir -p /lib /lib/i386 /lib/i86
# do not build for languages other than C,
# anyway not any libraries which need more than a C compiler
#
# also make sure we can build both i386 and i86 libraries
fix Makefile '
/\$(LIB.*)\/libm2\.a:/,/^$/d
/\$(LIB.*)\/libp\.a:/,/^$/d
/libm2/d
/libp/d

/^LIB=/s|/usr.*|/lib/i86|
/^LIB386=/s|/usr.*|/lib/i386|
/^LIB86=/s|/usr.*|/lib/i86|
/`arch`/s||$(ARCH)|

/xargs rm/s||while read a; do rm "$$a"; done|
'
(
# We face a syntax recognitions problem in i86 assembler,
# work around by fixing the corresponding files...
  for a in \
i86/em/em_loi.s \
i86/em/em_lar2.s \
i86/em/em_sti.s \
i86/em/em_dup.s \
i86/em/em_blm.s \
i86/em/em_sar2.s \
\
i86/em/em_stb.s \
\
i86/em/em_cms.s \
\
i86/em/em_retarea.s \
i86/em/em_trp.s \
  ; do
    fix "$a" '
/mov$/s||movs|
/movb$/s||movsb|
/cmp$/s||cmps|
/zerow/s||space|
    '
  done
  fix i86/em/em_fp8087.s '
/#/s|#||
/fi.*one/s|one|(one)|
/.bigmin/s|bigmin.*|(&)|
  '
  fix i86/em/Makefile '
/^CC1/a\
CFLAGS2 = -O -D_MINIX -D_POSIX_SOURCE -Was-ack\
CC2     = $(CC) $(CFLAGS2) -c
/CC1.*em_fp8087/s|CC1|CC2|
  '
  ARCH=i386; export ARCH
  make clean
  make install
  make clean
  fix math/Makefile '
/^CFLAGS/s|$| -Was-ncc|
  '
  ARCH=i86; export ARCH
  make clean
  make install
)

# ---------- now relink the compiler against the new libs

# run 2: re-build the new compiler (in the "usual" file trees)
# using itself
___BUILD_ACK

# ---------- we have got a new compiler with new libs
# test it

which cc

cc -O2 -s -o /mtop/bin/helloworldagain /root/helloworld.c
/mtop/bin/helloworldagain
ls -l /mtop/bin/helloworld*

# ---------- rebuild commands
cd /mtop
rm -rf src
compress -d < SOURCES/CMD.TAZ | tar xf - src/commands
# fs for src/commands/de,
# kernel,mm for postmort, sdump
compress -d < SOURCES/SYS.TAZ | tar xf - \
                                src/fs \
                                src/kernel/const.h \
                                src/kernel/type.h \
                                src/kernel/proc.h \
                                src/mm/const.h \
                                src/mm/mproc.h \
                                src/mm/type.h \


cd src/commands

# make sure that aal creates reproducible archives
# and also apply small cosmetic fixes

# use the more common /tmp,
# make the D flag set 0 date, not trying to stat the program binary
# and also make this flag always active;
# make aal also gracefully handle archives with appended zeros
# (important for our reproducibility hack)
fix aal/archiver.c '
/\/usr\/tmp/s||/tmp|g
/struct stat statbuf;/,/distr_time = statbuf.st_mtime;/c\
\        distr_time = 0;
/^BOOL distr_fl/s||& = TRUE|
/while ((member = get_member()) != NIL_MEM)/s|NIL_MEM|& \&\& *(member->ar_name)|
/^#endif./c\
#endif
'
fix aal/local.h '
/undef BIGMACHINE/s|BIGMACHINE.*|BIGMACHINE|
'
fix aal/system.h '
/^#endif./c\
#endif
'
# let mkfs always assume '-d' with 0 time
# (stat(argv[0]) with an uninitialized buffer on stack without checking?...)
fix simple/mkfs.c '
/^int .* dflag;/s|;| = 1;|
/current_time = time(/,/bin_time =/d
/current_time = bin_time/s|bin_time|0|
'
# remove the binary bootcode installation from fdisk
fix ibm/fdisk.c '
/master bootstrap/,/^$/d
/memcpy(buffer, bootstrap,/d
/ and boot code installed/s|||
'

make install
echo "==== commands REBUILT! ===="

# ---------- rebuild kernel
cd /mtop
rm -rf src
# tar complains about missing hardlink targets... ok
compress -d < SOURCES/SYS.TAZ | tar xf - \
                                src/boot \
                                src/fs \
                                src/inet \
                                src/kernel \
                                src/lib \
                                src/Makefile \
                                src/mm \
                                src/tools \
                                || :
cd src

# enable networking with NE2000 and RTL8139, which can be useful,
# (then) PTYs can be necessary as well:
fix /usr/include/minix/config.h '
/^#define.ENABLE_DP8390/s|\([^9]\)0|\11|
/^#define.ENABLE_PCI/s|0|1|
/^#define.ENABLE_RTL8139/s|0|1|
/^#define.NR_PTYS/s|0|4|
'
# let Minix-2 initialize CR0,
# this should make FPU operations usable on bochs
# TenDRA and TinyC compilers need the presence of FPU
# thus we do not care about a situation where it would be absent
fix kernel/mpx386.s '
/over_flags:/a\
\        .data1  0x0F,0x20,0xC0          ! mov   eax, cr0\
\        and     ax, 65531               ! 65535-4==0xfffb, clear bit EM (2^2=4) to indicate presence of FPU\
\        or      ax, 32                  ! 32==0x20, set bit NE (2^5=32) to turn off MSDOS compat mode\
\        .data1  0x0F,0x22,0xC0          ! mov   cr0, eax\
\        .data1  0xDB,0xE3               ! fninit
'

( set -x; cd fs     && make fs )
( set -x; cd inet   &&      make install )
( set -x; cd kernel && make kernel )
( set -x; cd mm     && make mm )

mkdir -p /usr/mdec
( set -x; cd boot   && make install )
( set -x; cd tools  && make image /usr/bin/ps )

echo "==== kernel REBUILT! ===="

[ -f /boot.crossbuild ]  || mv /boot /boot.crossbuilt || :
[ -f /minix.crossbuild ] || mv /minix /minix.crossbuilt || :
ls -l /boot /boot.crossbuilt || :
cp /usr/mdec/boot /boot
ls -l /boot
cp tools/image /minix
sync
sleep 2
# sync was important here, for installboot to get it right
####installboot -d /dev/c0d0p0 /usr/mdec/bootblock boot
####installboot -m /dev/c0d0   /usr/mdec/masterboot
####
####edparams /dev/c0d0p0 '@---EDPARAMSARG---@'
####
####echo "==== ready to REBOOT ===="
# but actually we will not do any reboot of this system

# /bin/sh has not been rebuilt, replace with /usr/bin/sh
( set -x ; cmp /usr/bin/sh /bin/sh ) || (
  ls -l /usr/bin/sh /bin/sh
  set -x
  cp /usr/bin/sh /bin/sh.rebuilt
  mv /bin/sh.rebuilt /bin/sh
)

# no need to keep /mtop for the later life

( set -x
  cd /
# take the log as the last item, as full as one can get
  tar cvf - boot minix bin lib usr etc log* | compress > /dev/c0d0p1
)

sync
sleep 5
echo "===== a compressed tar archive has been created on /dev/c0d0p1"
# tell the outside world that it is time to kill the emulator,
# in the last block of the unused space past the root fs partition
#
# (of course, _if_ the emulator flushes the emulated disk to the storage)
for a in 1 2 3 4 5 6 7 8; do for b in 1 2 3 4 5 6 7 8; do
    echo DONEDON
done; done | dd seek=@---LASTBL---@ of=/dev/c0d0
echo "==== DONE ===="

/bin/sh </dev/console >/dev/console 2>&1

exit
