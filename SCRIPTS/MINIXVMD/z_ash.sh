#!bourne sh
# to be run by a Bourne-compatible shell
#
# cross-build ash - notoriously hard to...

# v.0.5 2023-02-19 an
# v.0.4 2023-02-05 an
# v.0.3 2022-09-24 an
# v.0.2 2022-08-08 an

set -e

. "$S"/z_.sh

set -x

rm -rf src/commands/ash

gzip -d < "$A"/SOURCES/CMD.TAZ | tar xvf - \
                                 src/commands/ash \


ACKDESCR="$top"/lib/ack/descr; export ACKDESCR

cd src/commands/ash
fix Makefile '
/^\/bin\/sh:/,/install/d
/\/usr\/bin\//s||'"$mtop"'&|g
/\/usr\/lib\//s||'"$mtop"'&|g
/\/usr\/bin\//!{
  /\/bin\//s||'"$mtop"'&|g
}
/\/usr\/lib\//!{
  /\/lib\//s||'"$mtop"'&|g
}
/CC.*mknodes/s|(CC)|(HOSTCC)|
/CC.*mksignames/s|(CC)|(HOSTCC)|
/CC.*mksyntax/s|(CC)|(HOSTCC)|
/CC.*mkinit/s|(CC)|(HOSTCC)|
/ -i /s|| |
/-wo /s|| |
/ -o bin/s|||
'
# do not expose unsuitable includes
mv sys sys.hide
# note a hack to skip a dependency on stdarg ;-)
fix mknodes.c '
/#include <stdio/a\
#include <string.h>\
#include <stdlib.h>
/^FILE \*infp/c\
FILE *infp;
/^main/,/}/{
  /if (argc != 3)/i\
\        infp = stdin;
}
/^main/i\
#define berror do{fprintf(stderr, "line %d: ", linno);fprintf(stderr,\
#define eerror );putc('"'"'\\n'"'"', stderr);exit(2);}while(0)\
#define error(x) berror (x) eerror\
#define error2(x,y) berror (x),(y) eerror\
#define error3(x,y,z) berror (x),(y),(z) eerror\
int main(int,char**), readline(), parsefield(),\
    parsenode(), output(), nextfield(), skipbl(),\
    outsizes(), outfunc(), indent();
/^error(/,/^}/d
/error([^,]*,[^,]*)/s|error|error2|
/error([^,]*,[^,]*,[^,]*)/s|error|error3|

/^main/s|^|int |
/^parsenode/s|^|int |
/^parsefield/s|^|int |
/^output/s|^|int |
/^outsizes/s|^|int |
/^outfunc/s|^|int |
/^indent/s|^|int |
/^skipbl/s|^|int |
/char \*malloc(/d
'
fix mkinit.c '
/^#include <fcntl.h>/a\
#include <stdlib.h>
#include <string.h>
/char \*malloc(/d
'
for a in \
shell.h \
mkbuiltins \
mksyntax.c \
mkinit.c \
; do
  fix "$a" '
/#include.*<sys\/cdefs\.h>/d
  '
done
#fix shell.h '
#/#define NULL/d
#'
for a in \
input.c \
parser.c \
var.c \
mkinit.c \
; do
  fix "$a" '
/__P(/{s|||;s|))|)|;}
  '
done
fix mystring.h '
/^#ifndef SYSV/,/^#define equal/{
  /^#define equal/!d
}
/^#define equal/i\
#undef NULL /* to avoid a problematic redefine */\
#include <string.h>
'
fix trap.c '
/sig_t sigact/s||void (*sigact)(int)|
'

which hostcc
HOSTCC=hostcc CC=cc make && make install

exit
