#!bourne sh
# to be run by a Bourne-compatible shell
#
# Assemble and boot the newly cross-built system,
# compile and run a helloworld program,
# (re)build everything natively: in z__rebuild.sh
#   userspace, the compiler, the libraries, userspace again, the kernel
# put the (reproducible) result in a directory
#
# 4 arguments:
#   the name of the disk image to create and use (temporary data)
#   the number of dd (512 byte) blocks in half the disk (aka KiB of the disk)
#   directory to create with full file data
#   hardware emulation command line, as for y_run.sh
#
# v.0.17 2023-02-26 an
# v.0.16 2023-02-23 an
# v.0.15 2023-02-19 an
# v.0.14 2023-02-17 an
# v.0.13 2023-02-16 an
# v.0.12 2023-02-12 an
# v.0.11 2023-02-11 an
# v.0.10 2023-02-10 an
# v.0.9 2023-02-07 an
# v.0.8 2023-02-05 an
# v.0.7 2022-09-24 an
# v.0.6 2022-08-13 an

set -e

[ "$#" = 4 ]
diskimg="$1"; shift
blocks="$1"; shift
tdir="$1"; shift
hw="$1"; shift

. "$S"/z_.sh

lastbl="$(expr "$blocks" - 1)"

# for convenience, let us use differing edparams arguments
# depending on whether the hardware is real or emulated,
# this difference will not become a part of the resulting data
case "$hw" in
(-) edparamsarg='rootdev=hd1;processor=386;save' ;;
(*) edparamsarg='rootdev=hd1;processor=386;main(){boot};save' ;;
esac

build_rootfs(){
  cd "$B"
# NOTE we create usr/lib/gcc/i386 to satisfy
# the build of gcv (gcc aout converter),
# even though we do not build nor use gcc
  rm -rf ROOT_FS
  mkdir ROOT_FS \
        ROOT_FS/bin \
        ROOT_FS/dev \
        ROOT_FS/etc \
        ROOT_FS/minix \
        ROOT_FS/root \
        ROOT_FS/sbin \
        ROOT_FS/tmp \
        ROOT_FS/usr \
        ROOT_FS/usr/bin \
        ROOT_FS/usr/lib \
        ROOT_FS/usr/lib/ack \
        ROOT_FS/usr/lib/ack/i386 \
        ROOT_FS/usr/lib/ack/i86 \
        ROOT_FS/usr/lib/gcc \
        ROOT_FS/usr/lib/gcc/i386 \
        ROOT_FS/usr/lib/keymaps \
        ROOT_FS/usr/mdec \
        ROOT_FS/usr/sbin \
        ROOT_FS/usr/tmp \
        \
        ROOT_FS/mtop \


  chmod 1777 ROOT_FS/tmp ROOT_FS/usr/tmp
  cp -r "$mtop"/. ROOT_FS/mtop
  mv ROOT_FS/mtop/sbin/init ROOT_FS/sbin/init

# libc.a and em_cemcom.ansi are too big (>256KB) for mkfs,
# we have to split them
  for a in 3; do
    ( cd ROOT_FS/mtop/lib/ack/i"$a"86 &&
      set -x
      dd if=libc.a count=500          of=libc.a_1
      dd if=libc.a skip=500 count=500 of=libc.a_2
      dd if=libc.a skip=1000          of=libc.a_3
      rm libc.a
    )
  done
  ( cd ROOT_FS/mtop/lib/ack &&
    set -x
    dd if=em_cemcom.ansi count=500 of=e_c_a_1
    dd if=em_cemcom.ansi skip=500  of=e_c_a_2
    mv e_c_a_1 em_cemcom.ansi
    chmod +x em_cemcom.ansi
  )

# -------- a subset of the sources is to be put directly

  ( cd ROOT_FS/mtop
    gzip -d < "$A"/SOURCES/MINIX-VMD.SRC.TGZ | tar xvf - \
                                               include \
                                               src/etc \
                                               \
                                               src/cmd/simple/chmod.c \
                                               src/cmd/simple/chown.c \
                                               src/cmd/simple/mknod.c \
                                               src/cmd/simple/tee.c \
                                               src/vmd/cmd/simple/cp.c \
                                               src/vmd/cmd/simple/MAKEDEV.sh \
                                               || :

# we want something which is simplest to build (thus taking from Minix-2) :
    gzip -d < "$A"/SOURCES/CMD.TAZ | tar xvf - \
                                     src/commands/simple/tar.c \
                                     src/commands/simple/tr.c \

    mkdir initialsrc
    find src -name '*.c' | while read a ; do mv "$a" initialsrc ; done
    mv src/vmd/cmd/simple/MAKEDEV.sh initialsrc/MAKEDEV.sh
# mkproto does not survive a symlinked "circular path",
# hide it (we will restore it later)
    rm include/bsdcompat/mnx
  )

  mv ROOT_FS/mtop/src/etc/* ROOT_FS/etc
# nothing left in mtop/src
  ( set -x
    cd ROOT_FS/mtop
    rmdir \
          src/etc \
          src/cmd/simple \
          src/cmd \
          src/commands/simple \
          src/commands \
          src/vmd/cmd/simple \
          src/vmd/cmd \
          src/vmd \
          src \

  )
#
  mv ROOT_FS/etc/rc ROOT_FS/etc/rc_std
#
  cp ROOT_FS/mtop/usr/bin/sh ROOT_FS/bin/sh
  cat >ROOT_FS/root/helloworld.c <<'____'
#include <stdio.h>
int main(int argc, char **argv){
  printf("hello world\n");
  return 0;
}
____
  cat >ROOT_FS/etc/rc <<'____'
#!/bin/sh
exec </dev/console >/dev/console 2>&1
umask 022
ACKDESCR=/mtop/lib/ack/descr; export ACKDESCR
PATH=/bin:/usr/bin:/mtop/bin:/mtop/usr/bin:/sbin:/usr/sbin
TERM="minix"
export PATH TERM
mount -v -o remount,rw /dev/hd1 /
# at first we do not have tee
( set -e
(
  for a in 3; do
    ( cd /mtop/lib/ack/i"$a"86 &&
      set -x
      cat libc.a_1 libc.a_2 libc.a_3 >libc.a
    )
    ( cd /mtop/lib/ack &&
      set -x
      cat e_c_a_2 >>em_cemcom.ansi
    )
  done
# the first thing first :->
  ( set -x
    cc -O2 -s -o /mtop/bin/helloworld /root/helloworld.c
    helloworld
  )
#
  cd /mtop/initialsrc
# tee is for making a log while being able to watch the progress
  cc -O2 -D_MINIX -D_POSIX_SOURCE -s -o /mtop/bin/tee tee.c
) > /log00 2>&1
cat /log00
( ( set -x
  cd /mtop/initialsrc
# the first group is what is needed for MAKEDEV,
# tar is needed to handle further sources
  for a in \
chmod \
chown \
mknod \
tr \
\
tar \
    ; do
    cc -O2 -D_MINIX -D_POSIX_SOURCE -s -o /mtop/bin/"$a" "$a".c
  done
# we need ln but the source is "cp.c"
  cc -O2 -D_MINIX -D_POSIX_SOURCE -s -o /mtop/bin/ln cp.c
  for a in cp mv rm; do
    ln /mtop/bin/ln /mtop/bin/"$a"
  done
#
  ( set -x; rm /mtop/lib/ack/i*86/libc.a_* /mtop/lib/ack/e_c_a_2 )
#
  ln /mtop/bin/chown /mtop/bin/chgrp
  cd /dev
  /mtop/initialsrc/MAKEDEV.sh std
  cd /mtop
  tar xvf /dev/hd2
  cd SOURCES
# (we do not want to depend on gzip, nor on [s]flate,
# not even on compress, instead pre-retar the sources into mtop/SOURCES/src)
#
# use non-gnu grep,
# to be compiled among the very first utils from the same path:
  cp extrasrc/grep.c src/cmd/simple/grep.c

# we need make (which is, due to the replaced sources, the Minix-2 one)
  cd src/cmd
  ( cd make
    cc -O2 -Dunix -D_MINIX -D_POSIX_SOURCE -s -o make *.c
    ( set -x; cp make /mtop/bin/make )
  )
# to pave the way further we need some utils which at least on Minix-2
# are not built by "make all" in the suitable order
  cat >/mtop/bin/arch <<'===='
#!/bin/sh
case "$1" in
-b) echo ibm ;;
*) echo i386 ;;
esac
exit
====
  chmod +x /mtop/bin/arch
  ( cd simple
    for a in \
ed \
grep \
sed \
wc \
    ; do
      cc -O -s -o /mtop/bin/"$a" "$a".c
    done
  )
  cc -O -s -o /mtop/bin/install /mtop/SOURCES/src/vmd/cmd/simple/install.c
# some paths (like /usr/include/minix/config.h)
# are being used directly, give them them!
# better not to expose our includes to possible
# "make install", not using "ln -s" here:
  cp -rp /mtop/include/. /usr/include
# and also re-add the symlink "bsdcompat/mnx -> .."
  ln -s .. /usr/include/bsdcompat/mnx

# now try to build "everything" but pascal|modula-2|gnu

# environment can be reset, put the descr in its expected place
  cp /mtop/lib/ack/descr /usr/lib/ack
# we will later need its original contents as well
  cp /mtop/lib/ack/descr_ /usr/lib/ack
# Makefiles are referring to /usr/lib/$(CC)/... paths
  ln -s ack /usr/lib/cc
  ln -s ack /usr/lib/kcc
# carefully cherrypick from "make world"
# make libraries
  cd /mtop/SOURCES/src
  ( set -x
    cd lib
    ARCH=i386
    ( cd ack/mach/"$ARCH"       && make CC=cc ARCH="$ARCH" )
    ( cd ack/mach/generic/libfp && make CC=cc ARCH="$ARCH" )
    ( cd ack/setjmp             && make CC=cc ARCH="$ARCH" )
    make CC=cc ARCH="$ARCH"
    ( cd ../bsd/lib             && make CC=cc ARCH="$ARCH" )
    ( cd ack/mach/minix.i86     && make CC=cc ARCH="$ARCH" bootstrap )
  )
  : "==== libraries READY ===="
# make all commands
  ( set -x
    ( cd cmd     && make install )
    ( cd bsd/cmd && make install )
    ( cd sys     && make install )
    ( cd vmd/cmd && make install )
# ed and make have been built implicitly,
# adding grep, diff and awk, not present among the built utilities:
# (use non-gnu grep and provide
# non-gnu diff (without unified diff, c'est la vie) and awk)
    cc -O -s -o /usr/bin/grep /mtop/SOURCES/extrasrc/grep.c
    cc -O -s -o /usr/bin/diff -D_POSIX_SOURCE /mtop/SOURCES/extrasrc/diff.c
    ( cd /mtop/SOURCES/extrasrc/awk && make - all && make - install )
  )
  : "==== all we needed READY ===="

# now let us (re)build the compiler and the rest
  cd /mtop
# restore the sources for rebuild
  ( set -x; rm -rf SOURCES/src; tar xf /dev/hd2 SOURCES/src )
#
  sh SOURCES/z__rebuild.sh
# z__rebuild.sh shall never return
  echo "OOPS z__rebuild.sh has returned"
  exit 1
) 2>&1 || >/Trouble ) | tee -a /log00
# [ is a builtin
  [ ! -f /Trouble ]
)
echo "BAAAAAAAAAAAAAAAAAAAAAAAAD"
/bin/sh
____
}

build_datapart()(
  rm -rf SOURCES
# -------- collect the sources which we want to pass on
  mkdir SOURCES
  ( cd SOURCES
# ------------------------------------ extra source files
    mkdir extrasrc
# use/provide the non-gnu grep, diff and awk
# as well as the Minix-2 ed
# which is assumed by ackpack build, and also Minix-2 make;
# fdisk is missing in Minix-vmd sources but we like it
    gzip -d < "$A"/SOURCES/CMD.TAZ | tar xvf - \
                                     src/commands/awk \
                                     src/commands/make \
                                     src/commands/simple/diff.c \
                                     src/commands/simple/ed.c \
                                     src/commands/simple/grep.c \
                                     src/commands/ibm/fdisk.c \

# remove the binary bootcode installation from fdisk
    ffix src/commands/ibm/fdisk.c '
/master bootstrap/,/^$/d
/memcpy(buffer, bootstrap,/d
/ and boot code installed/s|||
    '
# thus far, these file names do not collide with each other
    mv src/commands/awk                extrasrc
    mv src/commands/simple/diff.c      extrasrc
    mv src/commands/ibm/fdisk.c        extrasrc
    mv src/commands/simple/grep.c      extrasrc
# cv for ackpack must come from Minix-vmd, not Minix-2
    cp -rpv "$A"/SOURCES/cv/.          extrasrc/cv
# ------------------------------------ re-compressed ackpack sources
    bzip2 -d < "$A"/SOURCES/ackpack.tar.bz2 | compress > ackpack.TAZ
# ------------------------------------ our patch
    cp "$A"/PATCHES/patch.suspected.comparebug .
# ------------------------------------ our scripts
    sed '
/@---LASTBL---@/s||'"$lastbl"'|
    ' "$S"/z__rebuild.sh >z__rebuild.sh
# ------------------------------------
# Minix-vmd sources: include is already in place via mkfs,
# we could skip man, but then tar would complain
# about missing hard link targets
# (note, this implies/recreates "src" which we temporarily used above)
    gzip -d < "$A"/SOURCES/MINIX-VMD.SRC.TGZ | tar xf - man src
# apply the desired tweaks
# ------------------------
# aal: use the more common /tmp,
# make the D flag set 0 date, not trying to stat the program binary
# and also make this flag always active;
# make aal also gracefully handle archives with appended zeros
# (important for our reproducibility hack)
    fix src/cmd/aal/archiver.c '
/\/usr\/tmp/s||/tmp|g
/struct stat statbuf;/,/distr_time = statbuf.st_mtime;/c\
\        distr_time = 0;
/^BOOL distr_fl/s||& = TRUE|
/while ((member = get_member()) != NIL_MEM)/s|NIL_MEM|& \&\& *(member->ar_name)|
    '
# ------------------------
# flex: avoid the attempt to rebuild scan.c in flex
# (note that the "current date" when running is 1 January 1970,
# that's why mv instead of cp, the latter would create a "very old" file)
    fix src/bsd/cmd/flex-2.3.7/Makefile '
/^install:/s||& first_flex|
/^first_flex/,/^$/{
  /cp /s||mv |
}
    '
# ------------------------
# we need the Minix-2 ed, replace the file:
    mv src/commands/simple/ed.c      src/cmd/simple/ed.c
# ------------------------
# we need the Minix-2 make, replace the files:
    ( set -x; mv src/commands/make/* src/cmd/make )
# clean up the remnant of Minix-2 path names
    ( set -x; rmdir src/commands/* src/commands )
  )
# ------------------------------------
  tar cf datapart SOURCES
  rm -rf SOURCES
# datapart is here a plain tar archive
)

# start a system with cross-compiled: kernel, sh, cat, compiler

build_rootfs
build_datapart
# the system image in kernelsrc/src/sys/tools is named 1.7.0r0
# and is too big to be but into the file system via mkfs,
# indicate this for y_bootable.sh
sh -x "$S"/y_bootable.sh \
                         ROOT_FS \
                         "$top"/mdec/masterboot \
                         "$top"/mdec/bootblock \
                         "$top"/mdec/boot \
                         +kernelsrc/src/sys/tools/1.7.0r0 \
                         datapart \
                         "$diskimg" "$blocks" \
                         "$edparamsarg"

# keep it for reference/troubleshooting
###rm "$diskimg"

echo "============== $(date)"
sh "$S"/y_run.sh "$diskimg" "$blocks" "$diskimg" "$hw"
echo "============== $(date)"

# 
(
  [ -d "$tdir" ] && find "$tdir" -type d | xargs chmod u+w
  rm -rf "$tdir"
  mkdir "$tdir"
  cd "$tdir"
  dd if=../"$diskimg" skip="$blocks" | gzip -d | tar xvf -
  find . -type d | xargs chmod u+w
  chmod u+w etc/rc
  cat >etc/rc <<'____'
#!/bin/sh
umask 022
PATH=/bin:/usr/bin:/sbin:/usr/sbin
TERM="minix"
export PATH TERM
exec </dev/console >/dev/console 2>&1
case "$1" in
start|'')
  mount -v -o remount,rw /dev/hd1 /
  ( cd /tmp && rm -rf rc && compress -d </dev/hd2 | tar xvf - rc )
  [ -f /tmp/rc ] && exec /bin/sh /tmp/rc
  ;;
esac
exec /bin/sh /etc/rc_std "$@"
exit
____
# this is useful, but not here:
  mv log?? ..
# include files should be hardly executable
# (they become this by virtue of mkproto...)
  find usr/include -type f | xargs chmod -x
# same for ego descr files
  chmod -x usr/lib/ack/ego/i386descr usr/lib/ack/ego/i86descr
# and for a lot of other files which we do not care enough about...
  hash="$( ( find . -type f | LANG=C sort | xargs sha256sum ; find . -type l | LANG=C sort | ( while read a; do printf '%s\n' "$a"; readlink "$a"; done ) ) | sha256sum )"
  echo "%%% ${hash} ${tdir}"
)

exit
