#!bourne sh
# to be run by a Bourne-compatible shell
#
# a template which can be used to build a cross-compiler
# for Minix-vmd kernel and userspace
# on a Posix-like system
# you may need to edit this script (you have been warned)

# v.0.11 2023-03-05
# v.0.10 2023-02-20
# v.0.9 2023-02-19
# v.0.8 2023-02-18
# v.0.7 2023-02-11
# v.0.6 2023-02-03
# v.0.5 2023-01-28
# v.0.4 2023-01-17
# v.0.3 2022-09-24
# v.0.2 2022-08-08
# v.0.1 2022-08-05

# this script must be run before other z_?*.sh scripts except z_tools.sh

# watch out in the code below for places commented
# _here_and_now_
# which may need adjustments for specific compilers and similar

set -e

. "$S"/z_.sh

printf '%s\n' "================ hostcc is:"
ls -l "$(which hostcc)"
printf '%s\n' "================"

# use the available ANSI C compatible compiler
# NOTE more workarounds can be needed, depending
# on the available compiler, there are many implicit
# function declarations in the code, leading e.g. to
# conversions between integers and pointers,
# this _may_ have to be adjusted

# _here_and_now_
###CC='hostcc -Dregister= -Drindex=strrchr -DS_IFDIR=0040000'
CC='hostcc -D_PROTOTYPE\(x,y\)=x\ y -Dregister= -Drindex=strrchr -DS_IFDIR=0040000'
export CC
# to cater for an argument with a space inside
# we can not use the CC variable directly but need a function,
# even though the definition above works in make (evaluated by shell)
myCC(){
###  ( set -x; hostcc -Dregister= -Drindex=strrchr -DS_IFDIR=0040000 "$@" )
  ( set -x; hostcc -D_PROTOTYPE\(x,y\)=x\ y -Dregister= -Drindex=strrchr -DS_IFDIR=0040000 "$@" )
}

# commands from Minix-2 are good enough for building
gzip -d < "$A"/SOURCES/CMD.TAZ | tar xvf - \
                                 src/commands/make \
                                 src/commands/i386/acd.c \
                                 src/commands/i386/asmconv \
                                 src/commands/i386/Makefile \
                                 src/commands/aal \
                                 src/commands/autil \
                                 src/commands/awk \
                                 src/commands/byacc \
                                 src/commands/flex-2.3.7 \
                                 src/commands/m4 \
                                 src/commands/patch \
                                 src/commands/simple/compress.c \
                                 src/commands/simple/ed.c \
                                 src/commands/simple/sed.c \

cd src/commands

mkdir -p "$top"/bin "$top"/lib

### build some specific programs which do not depend on others,
### just to avoid bothering about them later:
#
# the old-style compress utility
myCC -s -o "$top"/bin/compress simple/compress.c
#
# tar capable to create reproducible archives
myCC -s -o "$top"/bin/sltar "$A"/SOURCES/sltar.c
#
# our reproducible-tweaked mkproto
# (set PATH_MAX to allow more advanced contents in a file system)
myCC -s -o "$top"/bin/mkproto -DPATH_MAX=4096 "$A"/SOURCES/mkproto.c
###

( cd simple && myCC -o ed ed.c && cp ed "$top"/bin ) || exit

# -------- now we have got "ed"

ed simple/sed.c <<'____'
1,$s/getline/local_&/
w
q
____
( cd simple && myCC -o sed sed.c && cp sed "$top"/bin ) || exit

# NOTE 2023-02-19 gcc Debian 10.2.1-6 with -O2 produces working sed,
# but buiding with -O yields a sed that behaves erratically,
# its first use in fix() fails with "no such command as" (nothing more)

# -------- now we have got "sed"

fix make/Makefile '
/ -i /s|| |
/\/usr\/bin/s||'"$top"'/bin|g
/install -S/d
/install -cs -o bin/s||install|
'
for a in \
make/h.h \
make/input.c \
make/reader.c \
; do
  fix "$a" '
/getline/s||local_&|g
  '
done
### needed under a particular Tendra compiler instance, harmless otherwise:
fix make/archive.c '
/searchtab(file, &stp->st_mtime,/s|&stp->st_mtime|(time_t *)&|
'
###
( cd make &&
  myCC -Dunix -D_MINIX -D_POSIX_SOURCE -c check.c
  myCC -Dunix -D_MINIX -D_POSIX_SOURCE -c input.c
  myCC -Dunix -D_MINIX -D_POSIX_SOURCE -c macro.c
  myCC -Dunix -D_MINIX -D_POSIX_SOURCE -c main.c
# _here_and_now_
# some compilers lack a definition of PATH_MAX,
# others bail out on redefinition, choose between:
###  myCC -DPATH_MAX=4096 -Dunix -D_MINIX -D_POSIX_SOURCE -c make.c
###  myCC -Dunix -D_MINIX -D_POSIX_SOURCE -c make.c
  myCC -Dunix -D_MINIX -D_POSIX_SOURCE -c make.c
###
  myCC -Dunix -D_MINIX -D_POSIX_SOURCE -c reader.c
  myCC -Dunix -D_MINIX -D_POSIX_SOURCE -c rules.c
  myCC -Dunix -D_MINIX -D_POSIX_SOURCE -c archive.c
  myCC -o make check.o input.o macro.o main.o make.o reader.o rules.o archive.o
  ./make - install
)
# -------- now we have got "make"

fix i386/Makefile '
/`arch`/s||i386|
/\/usr\/bin/s||'"$top"'/bin|g
/install -S/d
/install -l/s||sh -c '"'"'for a ; do ln acd "$$a"; done'"'"'|
/install -cs -o bin/s||install|
/-DDESCR[^ ]* /s|||
/-i /s|||
/mtools/s|^|######|
'
# let cc aka acd respect ACKDESCR environment variable
fix i386/acd.c '
/^#define LIB/a\
#define DESCR (getenv("ACKDESCR")?getenv("ACKDESCR"):"ack") /* respect environment, if any */
'
fix i386/asmconv/Makefile '
/-i$/s|||
/install -S/d
/install -cs -o bin/s||install|
/\/usr\/lib/s||'"$top"'/lib|
'
( cd i386 && make - all && make - install ) || exit

# -------- now we have got "acd" and "asmconv"

fix aal/Makefile '
/^CC=/d
/ -wo /s|| |
/LDFLAGS=-i/c\
LDFLAGS=
/\/usr\/bin/s||'"$top"'/bin|g
/install -S/d
/install -l/s||sh -c '"'"'for a ; do ln aal "$$a"; done'"'"'|
/install -cs -o bin/s||install|
'
fix aal/format.c '
/register width/s|register|int|
'
fix aal/long2str.c '
/register base;/s|register|int|
/register mod,/s|register|int|
'
# use the more common /tmp,
# make the D flag set 0 date, not trying to stat the program binary
# and also make this flag always active;
# include <unistd.h> to properly declare lseek,
# avoid introducing stdarg.h
fix aal/archiver.c '
/^BOOL distr_fl/s||& = TRUE|
/lseek()/c\
#include <unistd.h>\
void add(), do_object();
/\/usr\/tmp/s||/tmp|g
/struct stat statbuf;/,/distr_time = statbuf.st_mtime;/c\
        distr_time = 0;
/^add(/ivoid
/^do_object/ivoid
/error(.*)/{
  /(.*,.*,.*,.*,.*)/!s|\(error(.*\))|\1,"")|
  /(.*,.*,.*,.*,.*)/!s|\(error(.*\))|\1,"")|
  /(.*,.*,.*,.*,.*)/!s|\(error(.*\))|\1,"")|
  /(.*,.*,.*,.*,.*)/!s|\(error(.*\))|\1,"")|
  /(.*,.*,.*,.*,.*)/!s|\(error(.*\))|\1,"")|
}
/^#endif./c\
#endif
'
fix aal/rd.c '
/lseek()/c\
#include <unistd.h>
'
### reading/writing header fields is WRONG when type sizes
### differ between compilers, fix this:
fix aal/object.h '
/^#if BYTES_REVERSED/,/^#define SECTCNT/c\
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
fix aal/local.h '
/undef BIGMACHINE/s|BIGMACHINE.*|BIGMACHINE|
'
fix aal/system.h '
/^#endif./c\
#endif
'
( cd aal && make - all &&
  mv "$top"/bin/ar "$top"/bin/ar.hostnative &&
  make - install ) || exit

# do not use aal as "ar" (yet?) !
mv "$top"/bin/ar "$top"/bin/ar.cross
cp "$top"/bin/ar.hostnative "$top"/bin/ar

# -------- now we have got "aal" aka archiver (ar)

fix autil/Makefile '
/ -wo/s|||
/ -i /s|| |
/\/usr\/bin/s||'"$top"'/bin|g
/install -S/d
/install -cs -o bin/s||install|
'
fix autil/anm.c '
/register i;/s|register|int|
'
fix autil/asize.c '
/register i;/s|register|int|
'
( cd autil && make - all && make - install ) || exit

# -------- now we have got "anm" and "asize"

###/#-lm/s||-lm|
fix awk/Makefile '
/#-lm/s||-lm|
/ -wo -w/s|||
/^LDFLAGS/c\
LDFLAGS =
/ -i /s|| |
/\/usr\/bin/s||'"$top"'/bin|g
/install -S/d
/install -cs -o bin/s||install|
'
fix awk/e.c '
/^CELL \*Arith(),/s|^|static |
/^CELL \*Print(),/c\
static CELL *Print(), *Cat();\
CELL *Array(), *Element();
/^CELL \*If(),/s|^|static |
/^CELL \*Arg(),/s|^|static |
/^CELL \*Subst()/c\
static CELL *Subst();\
CELL *In(), *Getline(), *Delete(), *Close();
/^CELL \*Nulproc()/s|^|static |

/^CELL \*_Arg();/a\
static Return();\
static regexp *getpat();
'
fix awk/l.c '
/^#include "awk/a\
\
static follow(), follow2(), iskeywd(), isbuiltin(), scannum(), scanstr(), scanreg();
/c = fgetc(pfp);/s|c = fgetc(pfp);|if (pfp) & else c = EOF;|
'
fix awk/r.c '
/^#include "regexp/a\
\
static get1rec(), r_mkfld();\
static void close1();\
static char * awktmp();
/^close1(/ivoid
'
fix awk/v.c '
/^#define MAXFIELD/a\
\
static hash(), arrayelm();\
static CELL * install(), * _install();
/^CELL \*lookup(), \*install(), \*_install(),/s|\*install(), \*_install(),||
'
fix awk/y.c '
/^NODE \*node0/,/^CELL \*execute/{
  /^NODE \*node0/!{
    /^CELL \*mkcell()/!{
      /^CELL \*execute(),/!{
        s|^|static |
      }
      /^CELL \*execute(),/c\
CELL *execute();\
static CELL *lookup();
    }
  }
}
/^int forflg;/i\
static dousrfun(), skipeol(), isassign(), iscat(), isincdec();\

'
fix awk/regexp.c '
/register c;/s|register|int|
'
( cd awk && make - all && make - install ) || exit

# -------- now we have got "awk"

fix byacc/Makefile '
/^CFLAGS/s| -wo | |
/LDFLAGS. *=. *-i/c\
LDFLAGS=
/\/usr\/bin/s||'"$top"'/bin|g
/install -S/d
/install -cs -o bin/s||install|
'
fix byacc/error.c '
/^print_pos(/ivoid
'
fix byacc/main.c '
/^getargs(/ivoid
'
fix byacc/output.c '
1a\
\
void save_column(), output_stored_text(), output_trailing_text(), output_semantic_actions();
/^save_column(/ivoid
/^output_stored_text(/ivoid
/^output_trailing_text(/ivoid
/^output_semantic_actions(/ivoid
'
fix byacc/reader.c '
/^get_line(/ivoid
/^skip_comment(/ivoid
/^copy_ident(/ivoid
/^copy_text(/ivoid
/^copy_union(/ivoid
/^declare_tokens(/ivoid
/^declare_types(/ivoid
/^read_declarations(/ivoid
/^add_symbol(/ivoid
/^copy_action(/ivoid
/^free_tags(/ivoid
/^print_grammar(/ivoid
'
fix byacc/verbose.c '
/^verbose(/ivoid
'
( cd byacc && make - all && make - install ) || exit

# -------- now we have got "yacc"

fix flex-2.3.7/Makefile '
/^CFLAGS/s| -wo | |
/-wa -c scan/s| -wa | |
/LDFLAGS. *=. *-i/c\
LDFLAGS=
/\/usr\/bin/s||'"$top"'/bin|g
/\/usr\/lib/s||'"$top"'/data|g
/install -S/s|-S.* flex|flex|
/install -c -o bin/s||install|
/install -l/s||sh -c '"'"'for a ; do ln -s "$$(basename "$$0")" "$$a"; done'"'"'|
/install -d -o bin/s||install -d|
/^SKELETON_FILE/c\
SKELETON_FILE=use_-S_to_supply_path_to_flex.skel
/install flex.skel/s|install flex.skel .*|install flex.skel $(DESTDIR)$(AUXDIR)/flex.skel|
'
fix flex-2.3.7/dfa.c '
/register rule_num/s|register|int|
'
mkdir -p "$top"/data/flex
( cd flex-2.3.7 && make - all && make - install ) || exit

# make flex actually usable
mv "$top"/bin/flex "$top"/bin/flex_real
cat >"$top"/bin/flex <<____
#!/bin/sh
exec '${top}/bin/flex_real' -S'${top}/data/flex/flex.skel' "\$@"
exit
____
chmod +x "$top"/bin/flex

# -------- now we have got "flex" and "lex"

fix m4/Makefile '
/cc -i /s||$(CC) |
/\/usr\/bin/s||'"$top"'/bin|g
/install -S/d
/install -cs -o bin/s||install|
'
( cd m4 && make - all && make - install ) || exit

# -------- now we have got "m4"

fix patch/Makefile '
/^CFLAGS/s| -wo | |
/cc -i /s||$(CC) |
/\/usr\/bin/s||'"$top"'/bin|g
/install -S/d
/install -cs -o bin/s||install|
'
( cd patch && make - all && make - install ) || exit

# -------- now we have got "patch"
# (which can handle "context diffs", not "unified diffs")

cd "$B"

# the compiler itself
# ------------------------------------------------

bzip2 -d < "$A"/SOURCES/ackpack.tar.bz2 | tar xf -

cd ackpack

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

# this will look safer:
fix util/opt/lookup.h '
/#define IDL/s|100|200|
/s_name\[2]/s||s_name[IDL+2]|
'

fix util/opt/mktab.y '
/p-nodes,p->ex_operator,p->ex_lnode,p->ex_rnode);/s|p-nodes|(int)(&)|
'
fix util/opt/putline.c '
/register byte \*p/s|byte|char|
'
# follow the advice in the comments in this file,
# to avoid the remaining compiler dependencies:
fix util/opt/alloc.c '
/^int lsizetab/,/^}/{
s|(.*)|(line_t)|
}
/^int asizetab/,/^}/{
s|(.*)|(arg_t)|
}
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

# NOTE, a redefinition of CC (!)
CC="hostcc \
           -D_EM_WSIZE=4 -D_EM_LSIZE=4 -D_EM_PSIZE=4"

# we embed this value directly into the relevant Makefile
# without putting it in the environment:
###CC_FOR_EGO_CF="cc"
# NOTE CC_FOR_EGO_CF="$CC" can work with hostcc (as long as it is not ack?)
# but better safe than sorry, reduce optimization there as well
CC_FOR_EGO_CF="hostcc \
                      -D_EM_WSIZE=4 -D_EM_LSIZE=4 -D_EM_PSIZE=4"

# skip the Minix-specific "-S" flag
# and choose a separate compiler for ego/cf
fix Makefile '
/^CC =/c\
CC = exec '"$CC"'
/ -S [^ ]* /s|| |

/^\$l\/ego\/cf :/,/^$/{
  /\$(CC)/s||'"$CC_FOR_EGO_CF"'|
}
'

# yacc is not at a certain known path;
# stack size setting is not necessary nor available
for a in make/Make.* make/*/Make.*; do
  case "$a" in
  (*.|*_) continue ;;
  esac
  fix "$a" '
/\/usr\/bin\/yacc/{
s|/usr/bin/||
}

/-stack ..kw/s|||
  '
done

# ------------ for reference:
# if we hadn't built Minix awk:
## awk syntax incompatibility...
#for a in \
#lang/cem/cpp/tokcase.awk \
#lang/cem/comp/tokcase.awk \
#; do
#  fix "$a" '
#/^\/{/s||/\\{|
#  '
#done
#fix util/opt/pop_push.awk '
#/switch/s||nota&|
#'
# ------------

# we do not want "undefined reference to `ASSERT'" ...
fix lang/cem/comp/ival.g '
/ASSERT/s||LL_assert|
'

# let ar create easily verifiable libraries
for a in \
make/Make.ego \
make/Make.em \
make/Make.libbas \
make/Make.libocm \
make/Make.mod \
; do
  fix "$a" '
/ar cr/s|ar cr|ar Dcr|
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

### _here_and_now_
### (this can need corrections depending on your compiler) :
________________IF_USING_GCC_OR_SIMILAR(){
# gcc reacts on the file name suffixes,
# try to mitigate this
#####
# also compensate for a bug in pcc preprocessor
# (as of Debian pcc 1.2.0~DEVEL+20200630-2)
##### replacing /as\/share\/comm2\.y >/s||-Ias/share - < &|
fix make/i386/Make.as '
/as\/share\/comm2\.y >/s%as/share/comm2\.y%-Ias/share - < & | sed '"'"'/.#i/{h;s|#.*||;x;s|.*#|#|;H;x;};/^#include.*>./{h;s|>.*|>|;x;s|.*>||;H;x;};/^#endif./{h;s|.*|#endif|;x;s|#endif||;H;x;}'"'"'%
'
fix make/i86/Make.as '
/as\/share\/comm2\.y >/s%as/share/comm2\.y%-Ias/share - < & | sed '"'"'/.#i/{h;s|#.*||;x;s|.*#|#|;H;x;};/^#include.*>./{h;s|>.*|>|;x;s|.*>||;H;x;};/^#endif./{h;s|.*|#endif|;x;s|#endif||;H;x;}'"'"'%
'
fix make/i386/Make.cg '
/ \.\.\/\.\.\/\.\.\/ncg\/i386\/table |/s|| - <&|
'
fix make/i86/Make.cg '
/ \.\.\/\.\.\/\.\.\/ncg\/i86\/table |/s|| - <&|
'
}
________________IF_USING_GCC_OR_SIMILAR
###

# ------------ for reference:
# if we hadn't built Minix ed:
## work around ed difference
#fix modules/src/em_code/em.gen.ed '
#$a\
#w /dev/null
#'
# but we have built a compatible ed

# if we hadn't built Minix yacc:
## another yacc incompatibility
#fix as/share/comm4.c '
#/void yyparse/s||int yyparse|
#'
# but we have built a compatible yacc
# ------------

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

# for reference:
# unclear why we did apply this change earlier:
## try to use consistent declarations in em_opt
#fix util/opt/prototypes.h '
#/^void outshort/s|(short)|(int)|
#'
#fix util/opt/putline.c '
#/^outshort(short i)/s|(short|(int|
#'

CC="$CC" make

# ---------- we have got a new compiler; put its parts
# in some order similar to what the Minix-vmd upstream meant:
# (<target> should have been namespace-isolated as
# e.g. target/<target>
# and executables (passes) could have been separated from libraries,
# but we just follow upstream here)

# bin/                        front-end drivers
# include/                    target-independent includes
# lib/ack/                    target-independent compiler passes
# lib/ack/<target>/           target-dependent stuff
# lib/ack/<target>/include/   target-dependent includes
# lib/ack/<target>/lib/       helper libs and alike
# lib/ack/<target>/passes/    target-specific passes

mkdir -p \
      "$top" \
      "$top"/bin \
      "$top"/include \
      "$top"/lib/ack \
      "$top"/lib/ack/ego \
      "$top"/lib/ack/i386 \
      "$top"/lib/ack/i86 \
      "$top"/man \
      "$top"/man/man1 \
      "$top"/man/man5 \
      "$top"/man/man6 \


# do not try to install the parts which we did not build
fix Makefile '
/^install:/,/^$/{
  /if \[ -f make\/Make\.basic ] ; then/,/for m in/{
    /for m in/!d
  }
}
'

make \
 bin="$top"/bin \
 lib="$top"/lib/ack \
 man="$top"/man \
 INSTALL="install -c" \
 install

# ---------- and ego descr-data

( cd "$top" &&
  gzip -d < "$A"/SOURCES/MINIX-VMD.USR.TGZ | tar xvf - \
                                             lib/ack/ego/i386descr \
                                             lib/ack/ego/i86descr \
                                             lib/ack/descr

# make cc usable, by providing a suitable descr for acd,
# also let aal produce easily verifiable libraries
  fix lib/ack/descr '
/^AAL =/s|/.*|'"$top"/bin/aal'|
/AAL cr/s||AAL Dcr|
/^ACK_CPP =/s|$| -I'"$top"/include'|
/^ACK_CEM =/s|CPP_F|& -I'"$top"/include'|
/^L =/s|=.*|= '"$top"/lib'|
/import ARCH/a\
\
MNX_ARCH = i386
  '
) || exit

ACKDESCR="$top"/lib/ack/descr; export ACKDESCR

# depending on the host compiler used,
# em_opt segfaults while compiling some files,
# that's why we prepare to be able to shortcut the optimizer
# if/when needed

cp "$ACKDESCR" "$ACKDESCR"_noopt
#/^ACK_OPT =/s|\$A.*|cat|
#/^ACK_OPT =/s|$| -n|
#fix "$ACKDESCR"_noopt '
#/^ACK_OPT =/s|$| -n|
#'

# ========== now it is time to build suitable libraries
cd "$B"

CC="cc"

( cd "$top" &&
  gzip -d < "$A"/SOURCES/MINIX-VMD.SRC.TGZ | tar xvf - \
                                             include \

) || exit

# ensure that we begin from a clean page
rm -rf \
       src/lib \
       src/bsd/lib \
       src/sys/fs

# tar complains about missing hardlink targets... ok
gzip -d < "$A"/SOURCES/MINIX-VMD.SRC.TGZ | tar xvf - \
       \
       src/lib \
       src/bsd/lib \
       src/sys/fs \
       \
       || :

cd src

find lib bsd -name Makefile | (
  while read a; do
    fix "$a" '
/\/usr\//s||'"$top"'/|g
/\$(CC)\//s||ack/|
/-O9/s||-O|
/-O2/s||-O|
/^all:/s| man||
/^all:/s|...MAN.*||
    '
  done
)

# ack built with 64-bit compilers does not swallow 1e256 (spins forever)
# for the moment we do not care about fixing ack, working around instead
fix bsd/lib/libc/stdlib/strtod.c '
/1e256/s||1e255+1e255+1e255+1e255+1e255+1e255+1e255+1e255+1e255+1e255|
'

cd lib

# picking the necessary parts from
# src/lib/ack/mach/minix.i386/Makefile
# and
# src/lib/ack/mach/minix.i86/Makefile

ARCH=i386

( cd ack/mach/"$ARCH"       && make CC="$CC" ARCH="$ARCH" )
( cd ack/mach/generic/libfp && make CC="$CC" ARCH="$ARCH" )
( cd ack/setjmp             && make CC="$CC" ARCH="$ARCH" )

fix editline/Makefile '
/^install:/s| /.*||
'
fix dummy/Makefile '
/install -l/s|install.*|for a in libcurses libnbio libndbm libsdbm libtermcap ; do ln $L/libm.a $L/"$$a".a ; done|
'

make CC="$CC" ARCH="$ARCH"

( cd ../bsd/lib             && make CC="$CC" ARCH="$ARCH" )
# ARCH is preset to i86 there, we shall not change that:
( cd ack/mach/minix.i86     && make CC="$CC" bootstrap )

# ========== libraries done

# ==== we shall build utilities to handle
# ==== Minix file systems and boot data
# ==== (some for boot/bios and some for the host platform)

# we will have to include host headers for our host libraries
# _and_ Minix headers for Minix-specific data structures

# -------- make a copy of Minix includes

cd "$B"

cp -rp "$top"/include/. include

# it is here where we will have "namespaced" Minix includes

# -------- choose suitable standard types
#          for the sizes expected by Minix code
type08bit=char
type16bit=short
type32bit=int

# for the moment (Linux on x86_64) the only type which needs
# adjustment is "long"
# NOTE after the "long" substitution
# do not trust variable names, nor comments :)
typeconvert()(
  for a; do
    fix "$a" '
s|_t$|_minix&|g
s|_t[^_0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz]|_minix&|g
s|\([^_0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz]\)\(DIR[^_0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz]\)|\1minix_\2|g
s|\([^_0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz]\)\(dirent[^_0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz]\)|\1minix_\2|g
s|long  *int|'"$type32bit"'|g
s|long|'"$type32bit"'|g

s|ifndef _\(.*\)_\([TH]\)$|ifndef _m_\1_\2|
s|define _\(.*\)_\([TH]\)$|define _m_\1_\2|
    '
  done
)
includeconvert()(
  for a; do
    fix "$a" '/^#include.*</s|<\(.*\)>|<M_\1>|'
  done
)

# we will have to include our own headers for our host libraries
# _and_ Minix-vmd headers for Minix-specific data structures
# --- make "namespacing" for the includes, to be able
# to combine them with the host system's ones

( cd include &&
  for a in *; do
    mv "$a" M_"$a"
  done
)

find include -name '*.h' | sort | (
  while read a; do
    typeconvert "$a"
    includeconvert "$a"
  done
) 2>&1 | tee Minclude_convert.log

# -------- NOTE beware _here_and_now_-specific definitions
mybareCC(){
  ( set -x
    hostcc \
           -D__ACK__=1 -D_EM_WSIZE=4 -D_EM_LSIZE=4 -D_EM_PSIZE=4 \
           -Dregister= -Drindex=strrchr -DS_IFDIR=0040000 \
           \
           "$@"
  )
}
# we will use the namespaced Minix-vmd includes:
myCC(){
  mybareCC -I"$B"/include "$@"
}
myansiCC(){
###  mybareCC -I"$B"/include "$@"
  mybareCC -I"$B"/include -D_PROTOTYPE\(x,y\)=x\ y "$@"
}

# we only care about the "version 2 flex" file systems,
# for the sake of its longer file name components,
# to make further OS bootstrapping less painful

# fdisk seems to be missing in Minix-vmd?
# we add it from Minix-2
gzip -d < "$A"/SOURCES/CMD.TAZ | tar xvf - \
                                 src/commands/ibm/fdisk.c

# keymap utility will be needed for kernel build,
# let us prepare it in advance here
#
# kernel: we need at least some includes from there:
# (also presumably src/sys/fs and src/lib/os/minix/other
# but they have already been fetched, higher above)
gzip -d < "$A"/SOURCES/MINIX-VMD.SRC.TGZ | tar xvf - \
                                           src/vmd/cmd/simple/install.c \
                                           src/sys/cmd/simple/mkfs2f.c \
                                           src/sys/cmd/simple/keymap.c \
                                           \
                                           src/sys/kernel \

# tar complains about missing hardlink targets... ok
gzip -d < "$A"/SOURCES/MINIX-VMD.SRC.TGZ | tar xvf - \
                                           src/sys/cmd/boot \
                                           || :

cd src/commands/ibm

typeconvert fdisk.c

# skip automatic geometry reading,
# sort out disk structure definitions,
# correct the output formats,
# mark void functions as void,
# remove the binary bootcode installation
fix fdisk.c '
/^void getgeom()/,/^}$/{
  /open(/,/r < 0/d
}
/^#include <sys\/types\.h>/a\
#undef _SIZET
/^#include.*partition/s|<|<M_|
/%ld/s||%d|g
/_PROTOTYPE(int load_from_file/s|int|void|
/^load_from_file(/s|^|void |
/_PROTOTYPE(int save_to_file/s|int|void|
/^save_to_file(/s|^|void |
/_PROTOTYPE(int change_partition/s|int|void|
/^change_partition(/s|^|void |

/master bootstrap/,/^$/d
/memcpy(buffer, bootstrap,/d
/ and boot code installed/s|||
'

myCC -s -o fdisk fdisk.c
cp fdisk "$top"/bin

cd "$B"/src/vmd/cmd/simple

#### now we can (finally, given the necessary includes)
#### and need to begin using the cross-build Minix install program
fix install.c '
/^#include <sys\/types\.h>/a\
#undef _SIZET
/#include <a\.out\.h>/s|a|M_a|
'
myCC -s -o install install.c
rm "$top"/bin/install
cp install "$top"/bin

cd "$B"/src/sys/cmd/simple

typeconvert keymap.c
###includeconvert keymap.c
# fix manually instead
fix keymap.c '
/^#include <sys\/ioctl/{
  i\
#undef _SIZET
  s|<|<M_|
}
/^#include <time/{
  s|<|<M_|
  i\
#undef NULL
  a\
#include <M_sys/types.h>
}
/^#include <sys\/kbdio/s|<|<M_|
/^#include <minix/s|<|<M_|

/dprintf/s||my_&|

/^"u8_minix_t keymap_str/s||"unsigned char keymap_str|

/^static void read_keymap/i\
char *strdup(char *s);

/^static u16_minix_t cnv_value/s||static void cnv_value|
/^static u16_minix_t$/c\
static void
'
myCC -s -o keymap keymap.c

cp keymap "$top"/bin

cp "$B"/src/lib/os/minix/other/fslib.c .
typeconvert fslib.c
includeconvert fslib.c

cp -a ../../fs/. fs
typeconvert fs/*.h

# let mkfs always assume '-d' with 0 time
# (stat(argv[0]) with an uninitialized buffer on stack
# without checking for success?...)
fix mkfs2f.c '
/^int .* dflag;/s|;| = 1;|
/current_time = time(/,/bin_time =/d
/current_time = bin_time/s|bin_time|0|

/#include <minix/s|minix|M_&|
/#include <fs/s|fs|M_&|
/#include "\.\.\/\.\.\//s||#include "|
/#include <unistd\.h>/c\
#define swab hide_swab\
#include <unistd.h>\
#undef swab
/^#include <sys\/types\.h>/a\
#undef _SIZET\
#undef NULL /* some compilers bail out at its redefinition */\
#include <M_sys/types.h>
/getline/s||local_&|
/^block_t sizeup(/,/^}$/{
  /open(/,/return/c\
\  return 0;
}
/^void check_mtab(/,/^}$/{
  /^{/,/^}$/c\
{ return; }
/%ld/s||%d|g
}
'
typeconvert mkfs2f.c
# unfix a problematic place:
fix mkfs2f.c '
/#include.*dirent\.h/s|minix_|M_|
'

mv fs M_fs

myCC -I. -s -o mkfs mkfs2f.c fslib.c
cp mkfs "$top"/bin

cd "$B"/src/sys/cmd/boot

# first build the stuff running on BIOS
mkdir "$top"/mdec
make bootblock masterboot extboot
ACKDESCR="$ACKDESCR"_noopt make boot
for a in bootblock masterboot extboot boot ; do
  make MDEC="$top"/mdec "$top"/mdec/"$a"
done

# boot stuff to run under Posix: edparams, installboot

# NOTE edparams.c is different between Minix-2 and Minix-vmd
# which seems to make it easier to crossbuild for -vmd

typeconvert edparams.c
fix edparams.c '
/^#include <sys\/types\.h>/a\
#undef _SIZET
/^#include <termios\.h>/a\
#include <M_sys/types.h>
'
myCC -s -o edparams edparams.c

cp rawfs.c rawfs_unix.c
typeconvert rawfs_unix.c
fix rawfs_unix.c '
/^#include <sys\/types\.h>/a\
#undef _SIZET
/#include <minix/s|minix|M_&|
/#include <sys\/dir/s|sys|M_&|
/#include <sys\/types\.h>/a\
#include <M_sys/types.h>
/#include "/s|"|"h_unix/|
'

mkdir h_unix
cp *.h h_unix
typeconvert h_unix/*.h

mkdir h_unix/fs
cp "$B"/src/sys/fs/*.h h_unix/fs
typeconvert h_unix/fs/*.h
includeconvert h_unix/fs/*.h

# unfix wrong fixes
for a in \
h_unix/fs/buf.h \
rawfs_unix.c \
; do
  fix "$a" '
/M_minix_dirent/s||M_dirent|
  '
done

# avoid redefines which make some compilers to bail out
fix rawfs_unix.c '
/^#include <M_minix\/const\.h>/i\
#undef NULL
'

# NAME_MAX here is the max length of a file name component,
# 14 could be enough (for vanilla Minix)
myCC -Ih_unix -DNAME_MAX=512 -c rawfs_unix.c

mkdir h_unix/kernel
cp "$B"/src/sys/kernel/*.h h_unix/kernel
typeconvert h_unix/kernel/*.h

typeconvert installboot.c
fix installboot.c '
/#include <minix/s|minix|M_&|
/#include <sys\/types\.h>/a\
#undef _SIZET\
#include <M_sys/types.h>
/#include <a\.out\.h>/s|a|M_a|
/#include "/s|"|"h_unix/|
/DIOCGETP/d
/%ld/s||%d|g
/^#include <M_minix\/const\.h>/i\
#undef NULL
'
myCC -c -DUNIX installboot.c

myCC -s -o installboot installboot.o rawfs_unix.o

cp edparams installboot "$top"/bin

# =====================
# Minix-vmd needs a different ack-format to aout converter

set -x

cd "$B"

cp -rpv "$A"/SOURCES/cv/. cv

cd cv
CC="hostcc"

mv "$top"/lib/ack/cv "$top"/lib/ack/cv.minix2
# Minix-vmd cv is written with the assumptions of
# a platform with sizeof(short)==2, sizeof(long)==4
# our variant uses i16_t u16_t i32_t u32_t
# choose here in -D suitable data types valid on the host platform
# and hope that these [iu][13][62]_t themselves do not mean
# something else in the host sys/types.h,
# then you would have to tweak the cv source
( set -x
  $CC -s -o "$top"/lib/ack/cv -Di16_t=short -Di32_t=int -Du16_t='unsigned short' -Du32_t='unsigned int' cv.c rd.c rd_bytes.c
)

exit
