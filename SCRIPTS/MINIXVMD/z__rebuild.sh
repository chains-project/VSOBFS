#!bourne sh
# rebuilding ackpack under i386 Minix-vmd
#
# uses:
#   @---LASTBL---@
#
# v.0.10 2023-02-25
# v.0.9 2023-02-17
# v.0.8 2023-02-15
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

# a hackish way to check which files have been rebuilt
# or possibly not:
# (the date at boot is 1 January 1970)
# let all written files get a well noticeable timestamp
# of 2 February
date 0202700000

# ack can not rebuild oneself without the ack-specific pre-built parts
# of libc, that's why we can not easily clean up the libraries
#
# instead we let object files be replaced in the library one-by-one
#
# the build integrity is anyway confirmed by the final reproducibility
# which must be checked in any case, against multiple building platforms

___BUILD_ACK(){

cd /mtop
rm -rf ackpack
compress -d <SOURCES/ackpack.TAZ | tar xf -
cd ackpack

# ackpack shall use the Minix-vmd cv, not the Minix-2 one
fix make/minix/Make.cv '
/ cv\/cv\.c /s|-o.*|-o $@ -D_MINIX -I/mtop/SOURCES/extrasrc/cv /mtop/SOURCES/extrasrc/cv/cv.c /mtop/SOURCES/extrasrc/cv/rd.c /mtop/SOURCES/extrasrc/cv/rd_bytes.c|
'

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

p /mtop/lib/ack/cv 600000
p /mtop/lib/ack/em_cemcom.ansi 600000

# Values below allow self compilation of ACK with -O2
p /mtop/lib/ack/ego/bo 786432
p /mtop/lib/ack/ego/ca 786432
p /mtop/lib/ack/ego/cf 786432
p /mtop/lib/ack/ego/cj 786432
p /mtop/lib/ack/ego/ic 1179648
p /mtop/lib/ack/ego/sp 786432
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
      /usr/lib/ack \
      /usr/lib/ack/ego \
      /usr/lib/ack/i386 \
      /usr/lib/ack/i86 \
      /usr/man \
      /usr/man/man1 \
      /usr/man/man2 \
      /usr/man/man3 \
      /usr/man/man4 \
      /usr/man/man5 \
      /usr/man/man6 \
      /usr/man/man7 \
      /usr/man/man8 \


make lib=/usr/lib/ack install

cp /mtop/lib/ack/ego/i386descr \
   /mtop/lib/ack/ego/i86descr \
                              /usr/lib/ack/ego
}
# end of ___BUILD_ACK()

# run 1: build a new compiler in the "usual" file trees,
# using the one in /mtop
___BUILD_ACK

# ---------- we have got a new compiler

# restore the original contents of descr
mv /usr/lib/ack/descr_ /usr/lib/ack/descr

# ensure that we do not carry on ACKDESCR
# nor run any of the earlier [cross-]built binaries (except /bin/sh)
unset ACKDESCR

# use the new compiler from the "usual" file trees
PATH=/bin:/usr/bin:/sbin:/usr/sbin
export PATH

# ---------- build the libraries
cd /mtop

cd SOURCES/src/lib
# do not build for languages other than C, nor gnu
# anyway not any libraries which need more than a C compiler
(
  ARCH=i386
  ( cd ack/mach/"$ARCH"       && make CC=cc ARCH="$ARCH" )
  ( cd ack/mach/generic/libfp && make CC=cc ARCH="$ARCH" )
  ( cd ack/setjmp             && make CC=cc ARCH="$ARCH" )
  make CC=cc ARCH="$ARCH"
  ( cd ../bsd/lib             && make CC=cc ARCH="$ARCH" )
# ARCH is preset to i86 there, we shall not change that:
  ( cd ack/mach/minix.i86     && make CC=cc bootstrap )
  : "==== libraries REBUILT ===="
  ls -l /usr/lib/ack/*/*.a
)

# ---------- now relink the compiler against the new libs

# run 2: re-build the new compiler (in the "usual" file trees)
# using itself from the "usual" file trees
___BUILD_ACK

# ---------- we have got a new compiler with new libs
# test it

which cc

( set -x
  cc -O2 -s -o /mtop/bin/helloworldagain /root/helloworld.c
  /mtop/bin/helloworldagain
  ls -l /mtop/bin/helloworld*
)

# ---------- rebuild commands and the kernel
cd /mtop

# add some extra margin to the disk space,
# this does not affect the commands build which already took
# all the space it needs, because of the earlier initial run,
# but may help the kernel build
rm -rf SOURCES/ackpack.TAZ ackpack

# fdisk is missing in the Minix/vmd source archive, provide it
cc -O -s -o /usr/bin/fdisk SOURCES/extrasrc/fdisk.c

# diff, grep and awk shall be built separately because in Minix-vmd
# they come from gnu, which we do not build
cc -O -s -o /usr/bin/grep SOURCES/extrasrc/grep.c
cc -O -s -o /usr/bin/diff -D_POSIX_SOURCE SOURCES/extrasrc/diff.c
( cd /mtop/SOURCES/extrasrc/awk && make - all && make - install )

cd SOURCES

# the contents in src has been already partly adjusted
# (yielding Minix-2 ed, Minix-2 make, reproducible aal)

cd src

# additional adjustments:
# let mkfs always assume '-d' with 0 time
for a in 1 2 ; do
  fix sys/cmd/simple/mkfs"$a"f.c '
/^int .* dflag;/s|;| = 1;|
/current_time = time(/,/bin_time =/d
/current_time = bin_time/s|bin_time|0|
  '
done

# let cc aka acd respect ACKDESCR environment variable
fix vmd/cmd/simple/acd.c '
/^#define LIB/a\
#define DESCR (getenv("ACKDESCR")?getenv("ACKDESCR"):"ack") /* respect environment, if any */
'

# allow executables with a certain entry point,
# for the sake of conversion from elf to aout
# which we anticipate to need in the future
fix sys/mm/exec.c '
/if (state\.entry_point != state\.exechdr\.a_entry)/s|)| \&\& (state.entry_point+=0xb4) != state.exechdr.a_entry)|
'

ourver=1.7.0r1
( set -x
  ( cd cmd     && make install )
  ( cd bsd/cmd && make install )
  ( cd sys     && make install )
  ( cd vmd/cmd && make install )
# somehow the chgrp program is missing,
# adding it manually:
  ln /usr/sbin/chown /usr/sbin/chgrp
  : "==== commands REBUILT ===="
# ensure that our revision definition is newer
# than the timestamp
  > sys/version/timestamp
  sleep 1
  cat >sys/version/revision.c <<____
int revision = 1;
____

  ( cd sys/kernel     && make )
  ( cd sys/mm         && make )
  ( cd sys/fs         && make )
  ( cd sys/task.stubs && make )
  ( cd sys/tools && make image="$ourver" "$ourver" )
  cp -p sys/tools/"$ourver" /minix/"$ourver"
#### no need to clean up the old one, it is never put into the file system
#### we know which version we replace
#### (a crosscompiled one, not to be used any longer)
#### clean up
###  old=1.7.0r0
###  rm /minix/"$old"
#
# no point in doing edparams here,
# we recreate the disk from outside anyway
######  edparams /dev/hd1 'image=/minix/'"$ourver"';save'
#
  : "==== kernel image REBUILT! ===="
)

rm -f /boot
cp /usr/mdec/boot /boot
ls -l /boot

####sync
####sleep 2
##### sync was important here, for installboot to get it right
####installboot -d /dev/hd1 /usr/mdec/bootblock boot
####installboot -m /dev/hd0 /usr/mdec/masterboot
####
####edparams /dev/hd1 '@---EDPARAMSARG---@'
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
  tar cvf - boot minix bin lib sbin usr etc log* | compress > /dev/hd2
)

sync
sleep 5
echo "===== a compressed tar archive has been created on /dev/hd2"
# tell the outside world that it is time to kill the emulator,
# in the last block of the unused space past the root fs partition
#
# (of course, _if_ the emulator flushes the emulated disk to the storage)
for a in 1 2 3 4 5 6 7 8; do for b in 1 2 3 4 5 6 7 8; do
    echo DONEDON
done; done | dd seek=@---LASTBL---@ of=/dev/hd0
echo "==== DONE ===="

/bin/sh </dev/console >/dev/console 2>&1

exit
