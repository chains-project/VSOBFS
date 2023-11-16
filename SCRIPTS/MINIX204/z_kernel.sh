#!bourne sh
# to be run by a Bourne-compatible shell
#
# build the kernel
# v.0.4 2023-02-05 an
# v.0.3 2022-09-24 an
# v.0.2 2022-08-08 an

set -e

. "$S"/z_.sh

# tar complains about missing hard link targets, ok
gzip -d < "$A"/SOURCES/SYS.TAZ | tar xvf - \
                                 src/fs \
                                 src/inet \
                                 src/kernel \
                                 src/lib \
                                 src/Makefile \
                                 src/mm \
                                 src/tools \
                                 || :

cd src

# descr_noopt has been prepared and used
# during building of the the cross-compiler,
# here it is needed again
( set -x; cd fs && ACKDESCR="$top"/lib/descr_noopt make i="$top"/include fs )
( set -x; cd inet && ACKDESCR="$top"/lib/descr_noopt make i="$top"/include inet )
( set -x; cd kernel && ACKDESCR="$top"/lib/descr_noopt make u="$top" kernel )
# this one went without crashing at optimization:
( set -x; cd mm && ACKDESCR="$top"/lib/descr make u="$top" mm )

( set -x; cd tools && ACKDESCR="$top"/lib/descr make u="$top" image )

# DONE

exit
