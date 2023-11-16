#!bourne sh
# to be run by a Bourne-compatible shell
#
# cross-build the native ack compiler
# v.0.7 2023-03-05
# v.0.6 2023-02-05
# v.0.5 2023-01-28
# v.0.4 2022-09-24
# v.0.3 2022-08-11
# v.0.2 2022-08-09

set -e

. "$S"/z_.sh

# ------------------------------------------------

if [ -d ackpack ]; then
  if [ -d ackpack.crossbuild ]; then
    rm -rf ackpack
  else
    mv ackpack ackpack.crossbuild
  fi
fi

bzip2 -d < "$A"/SOURCES/ackpack.tar.bz2 | tar xf -

cd ackpack

# applying fixes from cross compilation,
# as long as they do not impose memory overconsumption

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

### fix a "suspected" bug (masked by the optimizer?)
patch -p1 <"$A"/PATCHES/patch.suspected.comparebug

### fix an expression which is wrong on compilers
### where sizeof(long) != 4
### NOTE we replace by another, suitable here standard type,
### your choilce must depend on your build environment
# _here_and_now_
fix modules/src/em_code/em.c '
/#define.*fit16i(/s|long|int|g
'

### try to reduce the differences between 32 and 64 bit
### host platforms (otherwise em_opt crashes on some files)
# and avoid int-to-char conversion
fix util/opt/types.h '
/ long /s|| int |
/typedef char byte/s|char|unsigned &|
'
fix util/opt/getline.c '
/register long l/s| long | int |
'

fix util/opt/mktab.y '
/p-nodes,p->ex_operator,p->ex_lnode,p->ex_rnode);/s|p-nodes|(int)(&)|
'
fix util/opt/putline.c '
/register byte \*p/s|byte|char|
'

### reading/writing header fields is WRONG when type sizes
### and/or structure padding differ between compilers, fix:
fix modules/src/object/obj.h '
/ACK_BYTE_ORDER/,/^#define SECTCNT/c\
#define ACK_BYTE_ORDER 0x0123 /* just to _hopefully_ trigger suitable codepaths */\
#define uget2(c)        (Xchar((c)[0]) | ((unsigned) Xchar((c)[1]) << 8))\
#define get2(c)         ((short) uget2(c))\
#define Xput2(i, c)     (((c)[0] = (i)), ((c)[1] = (i) >> 8))\
#define put2(i, c)      { register int j = (i); Xput2(j, c); }\
#define get4(c)         (uget2(c) | ((long) uget2((c)+2) << 16))\
#define put4(l, c)      { register long x=(l); \\\
                          Xput2((int)x,c); \\\
                          Xput2((int)(x>>16),(c)+2); \\\
                        }\
#define SECTCNT 3       /* number of sections with own output buffer */\
'
# using <stdint.h> interacted weirdly
# with other standard includes (why?), we resort
# to picking _here_and_now_ suitable standard types
fix h/out.h '
/long.*o._.*;/s|long|int|
'
# a strange code, possibly a bug in our situation? disable:
fix as/share/comm6.c '
/if (sizeof(valu) != sizeof(long))/s||if (0)|
'
# just in case the size[of] matters:
for a in \
as/i86/mach0.c \
as/i386/mach0.c \
; do
  fix "$a" '
/#define valu_t long/s||#define valu_t int|
  '
done

# --- concerning the README:
# "make prepare-ack" is irrelevant as it merely adjusts
# the previous ack installation for minix-specific limitations
#
# "make fix-pascal-support" and similar for basic and occam look
# also minix-specific

# for reference: (from a port of ack to Linux)
######## our verdict: ego/cf becomes broken if built by ack
######## with ego-optimization i.e. with -O2
######## and even when built by gcc regardless optimization,
######## but works when built by ack with -O
### compiling with -O2 produces global optimizer
### which segfaults e.g. as follows:
###  cc -O2 -D_MINIX -D_POSIX_SOURCE -o acd -DARCH=\"i386\" acd.c
###  /..../passes/em_ego: /..../passes/ego/cf got a unix signal
###  make in /..../src/commands/i386: Exit code 1
### so the global optimizer is somewhat broken, at least when
### compiling itself, do not use it right now:
####CC="cc -O2"
###CC="cc -O"
## ------ from a different bootstrapping build of ack:
## now with "cc -O2" we get a different error:
##exec cc -O2 -c -DNDEBUG -o obj/eme/bhcst.o -Iobj -Ih -Imodules/h \
## -Imodules/src/alloc -Imodules/src/em_code -Imodules/src/read_em \
## -Imodules/src/string -Imodules/src/system \
## -DREADABLE_EM modules/src/em_code/bhcst.c
##/..../passes/em_opt2: error on line 23(CC_bhcst): procedure unterminated at eof
##CC="cc -O"
########
######## that's why we in the end resort to building ego/cf with "-O"
######## which apparently masks its bug

ACKDESCR="$top"/lib/descr
export ACKDESCR

# our crosscompiled ego/cf is not reliable
# (crashes on some files), thus no -O2 anywhere here
CC="cc -O"

# as for specifically building ego/cf itself:
# we embed this value directly into the relevant Makefile
# without putting it in the environment:
CC_FOR_EGO_CF="cc -O"

# choose a separate compiler for ego/cf
fix Makefile '
/^CC =/c\
CC = exec '"$CC"'

/^\$l\/ego\/cf :/,/^$/{
  /\$(CC)/s||'"$CC_FOR_EGO_CF"'|
}
'

# yacc is not at a certain known path
for a in make/Make.* make/*/Make.*; do
  case "$a" in
  (*.|*_) continue ;;
  esac
  fix "$a" '
/\/usr\/bin\/yacc/{
s|/usr/bin/||
}
  '
done

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

# getline() is present nowadays in stdio.h,
# let's hide it where this name is being used
### NOTE not to be confused with util/opt/getline.c
### which defines getlines(), not getline()
for a in \
util/cmisc/tabgen.c \
lang/basic/comp/basic.lex \
lang/basic/comp/compile.c \
; do
  fix "$a" '
/getline/s||local_getline|g
  '
done

# we do not need the other languages' front-ends
fix Makefile '
/\$l\/em_basic \\$/,/\$l\/i386\/libbas\.a \$l\/em_m2/d
/\$l\/em_pc \$l\/em_led/s||$l/em_led|
'

# Ehhh ackpack assumes that it is being built with a compiler where
# long is 32 bit -- the hack below should make it work
# even on 128-bit (?) platforms too
for a in \
lang/*/comp/Parameters \
; do
  fix "$a" '
/^#define.MAXSIZE/s|8|17|
  '
done

# we have to reuse several binaries from the build environment
fix make/Make.llgen '
/^\$x\/LLgen/,${
  /-lmodule/s|\$.*|cp '"$B"/ackpack.crossbuild/obj/bin/LLgen' $@|
}
'
fix make/Make.tabgen '
/^\$x\/tabgen/,${
  /CC/s|\$.*|cp '"$B"/ackpack.crossbuild/obj/bin/tabgen' $@|
}
'
fix make/Make.ego '
/^\$o\/ego\/mkclassdef /,/^$/{
  /CC/s|\$.*|cp '"$B"/ackpack.crossbuild/obj/ego/mkclassdef' $@|
}
/^\$o\/ego\/ra\/makeitems /,/^$/{
  /CC/s|\$.*|cp '"$B"/ackpack.crossbuild/obj/ego/ra/makeitems' $@|
}
'
fix make/Make.opt '
/^\$o\/opt\/mktab /,/^$/{
  /CC/s|\$.*|cp '"$B"/ackpack.crossbuild/obj/opt/mktab' $@|
}
'
fix make/Make.ncgg '
/^\$x\/ncgg/,${
  /CC/s|\$.*|cp '"$B"/ackpack.crossbuild/obj/bin/ncgg' $@|
}
'

CC="$CC" make

# ---------- we have got a new compiler; put its parts
# in some order similar to what the upstream meant:
# (<target> should have been namespace-isolated as
# e.g. target/<target>
# and executables (passes) could have been separated from libraries,
# but we just follow upstream here)

# bin/                    front-end drivers
# include/                target-independent includes
# lib/                    target-independent compiler passes
# lib/<target>/           target-dependent stuff
# lib/<target>/include/   target-dependent includes
# lib/<target>/lib/       helper libs and alike
# lib/<target>/passes/    target-specific passes

mkdir -p \
      "$mtop" \
      "$mtop"/bin \
      "$mtop"/include \
      "$mtop"/lib \
      "$mtop"/lib/ego \
      "$mtop"/lib/i386 \
      "$mtop"/lib/i86 \
      "$mtop"/man \
      "$mtop"/man/man1 \
      "$mtop"/man/man5 \
      "$mtop"/man/man6 \


# do not try to install the parts which we did not build
fix Makefile '
/^install:/,/^$/{
  /if \[ -f make\/Make\.basic ] ; then/,/for m in/{
    /for m in/!d
  }
}
'

make \
 bin="$mtop"/bin \
 lib="$mtop"/lib \
 man="$mtop"/man \
 INSTALL="install -c" \
 install

# ---------- and ego descr-data

( cd "$mtop"
  gzip -d < "$A"/SOURCES/USR.TAZ | tar xvf - \
                                   lib/ego/i386descr \
                                   lib/ego/i86descr
) || exit

# ---------- add the necessary toolchain utils

# NOTE because of the mkfs file size limitation
# we need a concatenation utility too (libc.a is too big
# to be put on the file system as a whole)

cd "$B"

if [ -d src/commands ]; then
  if [ -d src/commands.crossbuild ]; then
    rm -rf ackpack
  else
    mv src/commands src/commands.crossbuild
  fi
fi

gzip -d < "$A"/SOURCES/CMD.TAZ | tar xvf - \
                                 src/commands/i386/acd.c \
                                 src/commands/i386/asmconv \
                                 src/commands/i386/Makefile \
                                 src/commands/aal \
                                 src/commands/simple \


( cd src/commands/simple
  set -x
  cc -O -s -o cat cat.c
  cp cat "$mtop"/bin
)

cd src/commands

mkdir -p "$mtop"/bin "$mtop"/lib

fix i386/Makefile '
/`arch`/s||i386|
/\/usr\/bin/s||'"$mtop"'/bin|g
/install -l/s||sh -c '"'"'for a ; do ln -s acd "$$a"; done'"'"'|
/install -cs -o bin/s||install|
/-DDESCR[^ ]* /s|||
/mtools/s|^|######|
'
# let cc aka acd respect ACKDESCR environment variable
fix i386/acd.c '
/^#define LIB/a\
#define DESCR (getenv("ACKDESCR")?getenv("ACKDESCR"):"/usr/lib/descr") /* respect environment, if any */
'
fix i386/asmconv/Makefile '
/install -cs -o bin/s||install|
/\/usr\/lib/s||'"$mtop"'/lib|
'
( cd i386 && make - all && make - install ) || exit

# -------- now we have got "acd" and "asmconv"

fix aal/Makefile '
/^CC=/d
/\/usr\/bin/s||'"$mtop"'/bin|g
/install -l/s||sh -c '"'"'for a ; do ln -s aal "$$a"; done'"'"'|
/install -cs -o bin/s||install|
'
# use the more common /tmp,
# make the D flag set 0 date, not trying to stat the program binary,
# and also make this flag always active; 
# add some purely cosmetic fixes too
fix aal/archiver.c '
/^BOOL distr_fl/s||& = TRUE|
/\/usr\/tmp/s||/tmp|g
/struct stat statbuf;/,/distr_time = statbuf.st_mtime;/c\
        distr_time = 0;
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
( cd aal && make - all && make - install ) || exit

# -------- now we have got "aal"

# ---------- provide crtfiles and libraries

cp -v "$top"/lib/i386/*.o "$mtop"/lib/i386
cp -v "$top"/lib/i386/*.a "$mtop"/lib/i386
cp -v "$top"/lib/i86/*.o  "$mtop"/lib/i86
cp -v "$top"/lib/i86/*.a  "$mtop"/lib/i86

# ---------- make cc usable, by providing a descr for acd

( cd "$mtop"
  gzip -d < "$A"/SOURCES/USR.TAZ | tar xvf - \
                                   lib/descr

# NOTE here we anticipate the absolute paths
# to be used when running natively
  fix lib/descr '
/^L =/s|/.*|/mtop/lib|
/^AAL =/s|/.*|/mtop/bin/aal|
/^CPP_F =/s|$| -I/mtop/include|
  '
) || exit

exit
