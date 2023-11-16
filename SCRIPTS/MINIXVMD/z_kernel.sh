#!bourne sh
# to be run by a Bourne-compatible shell
#
# build the kernel

# v.0.6 2023-02-19 an
# v.0.5 2023-02-16 an
# v.0.4 2023-02-05 an
# v.0.3 2022-09-24 an
# v.0.2 2022-08-08 an

set -e

. "$S"/z_.sh

mkdir kernelsrc
cd kernelsrc

# tar complains about missing hard link targets, ok
gzip -d < "$A"/SOURCES/MINIX-VMD.SRC.TGZ | tar xvf - \
                                           src/sys \
                                           src/cmd/simple/init.c \
                                           src/vmd/cmd/simple/mount.c \
                                           || :
cd src/sys

# get rid of the harmful "dependencies"
find . -name Makefile | (
  while read a; do
    fix "$a" '
/\/usr\/include/d
/build -newrev/s||: &|
/build -name/s||echo 1.7.0r0|
/`arch`/s||i386|
/`arch -b`/s||ibm|
    '
  done
)

cat >version/revision.c <<____
int revision= 0;
____

ACKDESCR="$top"/lib/ack/descr; export ACKDESCR

( set -x; cd fs && make CC=cc )
( set -x; cd inet && make CC=cc )
for a in i386 ibm ; do
# we avoid "ln -s", for the sake of possible host platforms
# which lack symlinks
  cp kernel/assert.h kernel/"$a"/assert.h
done
( set -x; cd kernel && ACKDESCR="$ACKDESCR"_noopt make CC=cc MAKEFLAGS=' 'CC=cc )
( set -x; cd mm && make CC=cc )
( set -x; cd task.stubs && make CC=cc )

( set -x; cd tools && make image=1.7.0r0 1.7.0r0 )

# to be able to boot into the kernel, a /sbin/init executable is necessary
# and also a mount command to allow any changes to the booted disk
mkdir -p "$mtop"/sbin
cd "$B"/kernelsrc/src
cc -O -s -D_MINIX_SOURCE -o "$mtop"/sbin/init cmd/simple/init.c
cc -O -s -D_MINIX_SOURCE -o "$mtop"/bin/mount vmd/cmd/simple/mount.c

# DONE

exit
