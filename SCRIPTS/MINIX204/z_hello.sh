#!bourne sh
# to be run by a Bourne-compatible shell
#
# Assemble and boot the newly cross-built system,
# compile and run a helloworld program,
# (re)build everything natively: in z__rebuild.sh
#   userspace, the compiler, the libraries, userspace again, the kernel
# put the (reproducible) result in a directory
#
# 6 arguments:
#   the name of the disk image to create and use (temporary data)
#   the number of dd (512 byte) blocks in half the disk (aka KiB of the disk)
#   heads on the disk
#   sectors on the disk track
#   directory to create with full file data
#   hardware emulation command line, as for y_run.sh
#
# v.0.13 2023-02-20 an  instruct y_bootable to place image outside file system
#                       just to test that this also works
# v.0.12 2023-02-12 an
# v.0.11 2023-02-11 an
# v.0.10 2023-02-10 an
# v.0.9 2023-02-07 an
# v.0.8 2023-02-05 an
# v.0.7 2022-09-24 an
# v.0.6 2022-08-13 an

set -e

[ "$#" = 6 ]
diskimg="$1"; shift
blocks="$1"; shift
heads="$1"; shift
secs="$1"; shift
tdir="$1"; shift
hw="$1"; shift

. "$S"/z_.sh

lastbl="$(expr "$blocks" - 1)"

# for convenience, let us use differing edparams arguments
# depending on whether the hardware is real or emulated,
# this difference will not become a part of the resulting data
case "$hw" in
(-) edparamsarg='rootdev=d0p0;processor=386;save' ;;
(*) edparamsarg='rootdev=d0p0;processor=386;main(){boot};save' ;;
esac

build_rootfs(){
  cd "$B"
  rm -rf ROOT_FS
  mkdir ROOT_FS \
        ROOT_FS/bin \
        ROOT_FS/dev \
        ROOT_FS/etc \
        ROOT_FS/root \
        ROOT_FS/tmp \
        ROOT_FS/usr \
        ROOT_FS/usr/bin \
        ROOT_FS/usr/lib \
        ROOT_FS/usr/tmp \
        \
        ROOT_FS/mtop \


  chmod 1777 ROOT_FS/tmp ROOT_FS/usr/tmp
  cp -r "$mtop"/. ROOT_FS/mtop

# libc.a is too big (>256KB) for mkfs, we have to split it
  for a in '' 3; do
    ( cd ROOT_FS/mtop/lib/i"$a"86 &&
      set -x
      dd if=libc.a count=500 of=libc.a_1
      dd if=libc.a  skip=500 of=libc.a_2
      rm libc.a
    )
  done

# -------- a subset of the sources is to be put directly

  ( cd ROOT_FS/mtop
# src/fs for src/commands/de
# kernel,mm for postmort, sdump
    gzip -d < "$A"/SOURCES/SYS.TAZ | tar xvf - \
                                     include \
                                     src/fs \
                                     src/kernel/const.h \
                                     src/kernel/type.h \
                                     src/kernel/proc.h \
                                     src/mm/const.h \
                                     src/mm/mproc.h \
                                     src/mm/type.h \
                                     src/etc \


# this is redundant, but we do not care:
    gzip -d < "$A"/SOURCES/CMD.TAZ | tar xvf - \
                                     src/commands/scripts \
                                     src/commands/simple \


  )

  cp ROOT_FS/mtop/src/etc/* ROOT_FS/etc
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
ACKDESCR=/mtop/lib/descr; export ACKDESCR
PATH=/bin:/usr/bin:/mtop/bin:/mtop/usr/bin:/sbin:/usr/sbin
TERM="minix"
export PATH TERM
# at first we do not have tee
( set -e
(
  for a in '' 3; do
    ( cd /mtop/lib/i"$a"86 &&
      set -x
      cat libc.a_1 libc.a_2 >libc.a
    )
  done
# the first thing first :->
  ( set -x
    cc -O2 -s -o /mtop/bin/helloworld /root/helloworld.c
    helloworld
  )
#
  cd /mtop/src/commands/simple
# tee is for making a log while being able to watch the progress
  cc -O2 -D_MINIX -D_POSIX_SOURCE -s -o /mtop/bin/tee tee.c
) > /log00 2>&1
cat /log00
( (
  cd /mtop/src/commands/simple
# the first group is what is needed for MAKEDEV,
# install is needed to set stack size for compress,
# compress+tar are needed to handle further sources
  for a in \
chmod \
chown \
mknod \
tr \
\
install \
compress \
tar \
    ; do
    cc -O2 -D_MINIX -D_POSIX_SOURCE -s -o /mtop/bin/"$a" "$a".c
  done
  install -S 450k /mtop/bin/compress
# we need ln but the source is "cp.c"
  cc -O2 -D_MINIX -D_POSIX_SOURCE -s -o /mtop/bin/ln cp.c
  for a in cp mv rm; do
    ln /mtop/bin/ln /mtop/bin/"$a"
  done
#
  ( set -x; rm /mtop/lib/i*86/libc.a_* )
#
  ln /mtop/bin/chown /mtop/bin/chgrp
  cd /dev
  /mtop/src/commands/scripts/MAKEDEV.sh std
  cd /mtop
  tar xf /dev/c0d0p1
  compress -d < SOURCES/CMD.TAZ | tar xf - src/commands
# correct the aal source to let it create reproducible archives
# (we do not yet have "patch" but we have got "cp")
  cp SOURCES/src/commands/aal/archiver.c src/commands/aal/archiver.c
  cd src/commands
# we need make
  ( cd make
    cc -O2 -Dunix -D_MINIX -D_POSIX_SOURCE -s -o make *.c
    mv make make_1st
    ( set -x; ./make_1st install )
  )
# to pave the way further we need some utils which are
# not built by "make all" in the suitable order
  cat >/mtop/bin/arch <<'===='
#!/bin/sh
echo i386
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
      make "$a"
      cp "$a" /mtop/bin
    done
  )
# some paths (like /usr/include/minix/config.h)
# are being used directly, give them them!
# ln -s does not work... a copy is better anyway
  cp -rp /mtop/include/. /usr/include

# now try to build "everything"
# environment can be reset, put the descr in its expected place
  cp /mtop/lib/descr /usr/lib/descr
  make install
  echo "==== commands build completed ===="
# we will need MAKEDEV later on
  mkdir -p /usr/sbin
  cp -v /mtop/src/commands/scripts/MAKEDEV.sh /usr/sbin/MAKEDEV

# let "df" and "mount" be functional
  printroot >/etc/mtab

# now let us (re)build the compiler and the rest
  cd /mtop
# remove the no longer needed src, to free disk space
  rm -rf src
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

build_datapart(){
# -------- collect the sources which we want to pass on
  rm -rf SOURCES
  mkdir SOURCES

# re-compress
  bzip2 -d < "$A"/SOURCES/ackpack.tar.bz2 | compress > SOURCES/ackpack.TAZ
# Minix sources
  cp "$A"/SOURCES/CMD.TAZ SOURCES
  cp "$A"/SOURCES/SYS.TAZ SOURCES
# our patch
  cp "$A"/PATCHES/patch.suspected.comparebug SOURCES
# our scripts
  sed '
/@---LASTBL---@/s||'"$lastbl"'|
  ' "$S"/z__rebuild.sh >SOURCES/z__rebuild.sh

# corrected source files
  ( cd SOURCES
    gzip -d < "$A"/SOURCES/CMD.TAZ | tar xvf - src/commands/aal/archiver.c
# use the more common /tmp,
# make the D flag set 0 date, not trying to stat the program binary
# and also make this flag always active;
# make aal also gracefully handle archives with appended zeros
# (important for our reproducibility hack)
    fix src/commands/aal/archiver.c '
/\/usr\/tmp/s||/tmp|g
/struct stat statbuf;/,/distr_time = statbuf.st_mtime;/c\
\        distr_time = 0;
/^BOOL distr_fl/s||& = TRUE|
/while ((member = get_member()) != NIL_MEM)/s|NIL_MEM|& \&\& *(member->ar_name)|
    '
  )

  tar cf sources.tar SOURCES
  rm -rf SOURCES
  mv sources.tar datapart
# datapart is here a plain tar archive
}

# start a system with cross-compiled: kernel, sh, cat, compiler

build_rootfs
build_datapart
sh -x "$S"/y_bootable.sh \
                         ROOT_FS \
                         "$top"/mdec/masterboot \
                         "$top"/mdec/bootblock \
                         "$top"/mdec/boot \
                         +src/tools/image \
                         datapart \
                         "$diskimg" "$blocks" "$heads" "$secs" \
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
# this is useless here:
  rm -f etc/rc usr/lib/descr. usr/lib/descr_
  cat >etc/rc <<'____'
#!/bin/sh
umask 022
PATH=/bin:/usr/bin:/sbin:/usr/sbin
TERM="minix"
export PATH TERM
exec </dev/console >/dev/console 2>&1
case "$1" in
start)
  printroot >/etc/mtab
  ( cd /tmp && rm -rf rc && compress -d </dev/c0d0p1 | tar xvf - rc )
  [ -f /tmp/rc ] && exec /bin/sh /tmp/rc
  ;;
esac
exec /bin/sh /etc/rc_std "$@"
exit
____
# this is useful, but not here:
  mv log?? ..
# include files should be hardly executable
  find usr/include -type f | xargs chmod -x
# same for ego descr files
  chmod -x usr/lib/ego/i386descr usr/lib/ego/i86descr
#
  hash="$(find . -type f | LANG=C sort | xargs sha256sum | sha256sum)"
  echo "%%% ${hash} ${tdir}"
)

exit
