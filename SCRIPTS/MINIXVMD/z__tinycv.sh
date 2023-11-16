#!bourne sh
# building Tiny C Compiler by Tiny C compiler
# for use with Minix-vmd libraries under Minix-vmd
#
# v.0.2 2023-03-03
# v.0.1 2023-03-02

set -e

set -x

tver="$1"; shift

# we can encounter files with names of exactly 14 bytes
# which might be the file system's limit, thus a workaround:
_fix()(
  fixfile="$1"; shift
# to avoid losing the original if doing multiple fixes
  [ -f "$fixfile"_ ] || cp "$fixfile" "$fixfile"_
#
  cp "$fixfile" "$fixfile". || return
  sed "$@" "$fixfile". >"$fixfile"
  diff -c "$fixfile". "$fixfile" || :
)
fix()(
  printf '%s\n' "==== fixing '$1'" >&2
  tst="$(basename "$1")"
  case "$tst" in
  ??????????????*)
    ffile="$1"; shift
    cp "$ffile" fix.tmp.file
    _fix fix.tmp.file "$@"
    mv fix.tmp.file "$ffile"
    rm fix.tmp.file?
    ;;
  *) _fix "$@" ;;
  esac
)
# do not ever try this on 14-byte long names:
#ffix(){
#  fix "$@"
#  rm -v "$1". "$1"_
#}

# the source archives are expected
# to be present in /mtop

# let us use hd2 as the work space

mkfs -t 2f /dev/hd2
mkdir -p /mnt
mount /dev/hd2 /mnt
cd /mnt

# the compiler sources:
compress -d < /mtop/tinycc.TAZ | tar xf -
# free disk space
rm /mtop/tinycc.TAZ

# the libraries' sources:
compress -d < /mtop/SRC.TAZ | tar xf - \
                              src/bsd/lib \
                              src/lib \
                              src/sys/fs \
                              || :

# free disk space
rm /mtop/SRC.TAZ

# it is a certain tcc version which we handle
cd tinycc-"$tver"

# ==============================================
# Minix-specific TinyCC adjustments:

# compiler data placement:
libdest=/usr/lib/tcc
bindest=/usr/bin

# ----------------------------------------------------------
# add some files needed for the compiler build

cat >stdint.h <<'____'
/*
 * stdint.h - standard types
 */
/* $Id$ */

#ifndef _STDINT_H
#define _STDINT_H

/* int8_t is always a char, on all ACK platforms. */

typedef signed char     int8_t;
typedef unsigned char   uint8_t;
#define INT8_MAX        127
#define INT8_MIN        (-128)
#define UINT8_MAX       255

/* int16_t is always a short, on all ACK platforms. */

typedef signed short    int16_t;
typedef unsigned short  uint16_t;
#define INT16_MAX       32767
#define INT16_MIN       (-32768)
#define UINT16_MAX      65535

/* int32_t is either a int or a long. */

#ifndef _EM_WSIZE /* a fallback good for 32-bit -- rl */
#define _EM_WSIZE 4
#endif
#ifndef _EM_LSIZE /* a fallback good for 32-bit -- rl */
#define _EM_LSIZE 4
#endif
#ifndef _EM_LLSIZE /* a fallback good for 32-bit -- rl */
#define _EM_LLSIZE 4
#endif
#ifndef _EM_PSIZE /* a fallback good for 32-bit -- rl */
#define _EM_PSIZE 4
#endif
#if     _EM_WSIZE == 4
typedef signed int      int32_t;
typedef unsigned int    uint32_t;
#else
typedef signed long     int32_t;
typedef unsigned long   uint32_t;
#endif
#define INT32_MAX       2147483647
#define INT32_MIN       (-2147483648)
#define UINT32_MAX      4294967295

/* With TenDRA we have got longlongs */

#if _EM_LLSIZE == 8
typedef signed long long    int64_t;
typedef unsigned long long  uint64_t;
#define INT64_MAX  (0x7fffffffffffffffLL)
#define INT64_MIN  (-1-0x7fffffffffffffffLL)
#define UINT64_MAX (0xffffffffffffffffULL)
#else

/* With ACK we only get int64_t if longs are 8 bytes. */

#if _EM_LSIZE == 8
typedef signed long     int64_t;
typedef unsigned long   uint64_t;
#define INT64_MAX       2147483647LL
#define INT64_MIN       (-2147483648LL)
#define UINT64_MAX      4294967295ULL
#endif
#endif

#if _EM_LLSIZE == 8 || _EM_LSIZE == 8
typedef int64_t         intmax_t;
typedef uint64_t        uintmax_t;
#else
typedef int32_t         intmax_t;
typedef uint32_t        uintmax_t;
#endif

/* Pointers can be either 16 or 32 bits. */

#if _EM_PSIZE == 2
typedef int16_t         intptr_t;
typedef uint16_t        uintptr_t;
#ifndef _PTRDIFF_T
#define _PTRDIFF_T
typedef int16_t         ptrdiff_t;
#endif
#ifndef _SIZE_T
#define _SIZE_T
typedef uint16_t        size_t;
#endif
#define INTPTR_MAX      32767
#define INTPTR_MIN      (-32768)
#define UINTPTR_MAX     65535
#else
typedef int32_t         intptr_t;
typedef uint32_t        uintptr_t;
#ifndef _PTRDIFF_T
#define _PTRDIFF_T
typedef int32_t         ptrdiff_t;
#endif
#ifndef _SIZE_T
#define _SIZE_T
typedef uint32_t        size_t;
#endif
#define INTPTR_MAX      2147483647
#define INTPTR_MIN      (-2147483647)
#define UINTPTR_MAX     4294967295
#endif

/* Now those have been defined, these are always the same. */

#define PTRDIFF_MAX     INTPTR_MAX
#define PTRDIFF_MIN     INTPTR_MIN
#define SIZE_MAX        UINTPTR_MAX

/* format qualifiers */
#define PRIdMAX "ld"

#endif
____

cat >sys_mman.h <<'____'
#define PROT_READ      1
#define PROT_WRITE     2
#define PROT_EXEC      4
____

cat >mprotect.c <<'____'
#include <sys/types.h>
int mprotect (void *a, size_t b, int c) {
  return 0;
}
____

cat >sys_time.h <<'____'
#ifndef _SYS_TIME_H
#define _SYS_TIME_H

#ifdef __cplusplus
extern "C" {
#endif

struct timeval {
        long    tv_sec;         /* seconds */
        long    tv_usec;        /* and microseconds */
};

struct itimerval
{
        struct timeval it_interval;
        struct timeval it_value;
};

int   getitimer(int, struct itimerval *);
int   gettimeofday(struct timeval *restrict1, void *restrict2);
int   utimes(const char *, const struct timeval [2]); /* LEGACY */

#ifdef __cplusplus
}
#endif

#endif
____

cat >gettimeofday.c <<'____'
#include "sys_time.h"

#include <sys/types.h>
#include <time.h>

int gettimeofday(struct timeval *tv, void *tz) {
  tv->tv_sec  = time(NULL);
  tv->tv_usec = 0;
  return 0;
}
____

# add the include file corresponding to setjmp.s
# (from the TenDRA Minix-2 port)
# NOTE this should be reviewed and aligned
# with register usage in TinyCC, but may even work as-is
cat >include/setjmp.h <<'____'
#ifndef __HACKED_SETJMP_INCLUDED
#define __HACKED_SETJMP_INCLUDED

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _SETJMP_H
#define _SETJMP_H

#if 0
#ifndef _ANSI_H
#include <ansi.h>
#endif
#endif /* 0 */

#include <sys/types.h>  /* sigset_t */

typedef struct __jmp_buf_tag {
  int __regs[6];
  int __flag;
  sigset_t __mask;
} jmp_buf[1];

#define JB_BX   0
#define JB_SI   1
#define JB_DI   2
#define JB_BP   3
#define JB_SP   4
#define JB_PC   5

int __setjmp(jmp_buf env, int savemask);
void __longjmp(jmp_buf env, int val);

#define setjmp(env)       __setjmp((env), 1)
#define longjmp(env, val) __longjmp((env), (val))

#ifdef _POSIX_SOURCE
typedef jmp_buf sigjmp_buf;
#define sigsetjmp(env, savemask) __setjmp((env), (savemask))
#define siglongjmp(env, val)     __longjmp((env), (val))
#endif

#ifdef _MINIX
#define _setjmp(env)       __setjmp((env), 0)
#define _longjmp(env, val) __longjmp((env), (val))
#endif

#endif  /* _SETJMP_H */

#ifdef __cplusplus
}
#endif

#endif  /* __HACKED_SETJMP_INCLUDED */
____

# ----------------------------------------------------------
# let it find the environ variable
fix tccrun.c '
/^#elif defined(__OpenBSD__) || defined(__NetBSD__)/s/$/ || defined(_MINIX)/
'
# let it define these important macros
fix tccpp.c '
/"__linux__\\0"/,/"__linux\\0"/c\
\    "_MINIX\\0"\
\    "__minix\\0"\
\    "__minix_vmd\\0"\
\    "_BSD_ANSI_LIB_SRC\\0"\
\    "_EM_WSIZE 4\\0"\
\    "_EM_PSIZE 4\\0"\
\    "_EM_SSIZE 2\\0"\
\    "_EM_LSIZE 4\\0"\
\    "_EM_LLSIZE 8\\0"\
\    "_EM_FSIZE 4\\0"\
\    "_EM_DSIZE 8\\0"
'

# ----------------------------------------------------------
# let it tell what we mean
fix tcc.c '
/" Linux"/s||" Minix-vmd"|g
'

# ----------------------------------------------------------
# adjust to conform/add to the tricks we are going to play
# at compilation
fix tcc.h '
/<stdint.h>/s|.*|/* & -- this include does not happen anyway */|
/extern float strtof (const char \*__nptr, char \*\*__endptr);/d
/extern long double strtold (const char \*__nptr, char \*\*__endptr);/d
/define TCC_IS_NATIVE/s|.*|/* & */|
'
fix tccrun.c '
/# include <sys\/mman\.h>/s||# include "sys_mman.h"|
'
fix tccgen.c '
/define TCC_IS_NATIVE_387/s|.*|/* & */|
'

# ----------------------------------------------------------
# add support for producing aout executables

cp /mtop/elf2aout.c /mtop/elf.h .
fix elf.h '
/<stdint.h>/s||"stdint.h"|
'
fix tcc.h '
/#define dwarf_line_str_section/a\
\
/* ------------ elf2aout.c ------------ */\
#ifdef TCC_GENERATE_AOUT\
PUB_FUNC int elf2aout(const char *elf);\
#endif\

'
fix tcc.c '
/tcc_delete(s);/i\
#ifdef TCC_GENERATE_AOUT\
    {   int e2a;\
        if (s->output_type == TCC_OUTPUT_EXE) {\
            if ((e2a = elf2aout(s->outfile)) != 0)\
                return e2a;\
        }\
    }\
#endif\

'
fix libtcc.c '
/s->include_stack_ptr = s->include_stack;/a\
\    /* do not try dynamic linking on this platform */\
\    s->static_link = 1;
'
# let tinycc use a single section for all data
fix tccgen.c '
/rodata_section/s||data_section|
'
# use 0 loading address
fix i386-link.c '
/#define ELF_START_ADDR 0x08048000/s|0x08048000|0|
'

# ----------------------------------------------------------
# enable leading underscore as default;
# make it possible to override hardwired defaults via environment;
# link crtso.o as the first and libend.a as the last item

fix libtcc.c '
/enable this if you want symbols with leading underscore/a\
\    s->leading_underscore = 1;

/tcc_add_crt(s, "crt1\.o");/c\
\            if (getenv("CONFIG_TCC_CRT1"))\
\                tcc_add_crt(s, getenv("CONFIG_TCC_CRT1"));\
\            else tcc_add_crt(s, "crtso.o");
/tcc_add_crt(s, "crti\.o");/c\
\        if (getenv("CONFIG_TCC_CRTI"))\
\            tcc_add_crt(s, getenv("CONFIG_TCC_CRTI"));
'
fix tccelf.c '
/tcc_add_crt(s1, "crtn\.o");/c\
\            if (getenv("CONFIG_TCC_CRTN"))\
\                tcc_add_crt(s1, getenv("CONFIG_TCC_CRTN"));\
\            else tcc_add_library_err(s1, "end");
'

cat > config.h <<____
#define CONFIG_TCCDIR "${libdest}"
#define CONFIG_USR_INCLUDE "/usr/include"
#define TCC_VERSION "git-${tver}_minixvmd"
#define GCC_MAJOR 0
#define GCC_MINOR 0
#define CC_NAME CC_tinycc
#define TCC_GENERATE_AOUT
____


# ----------------------------------------------------------
# last but not least, let TinyCC produce reproducible results
fix tccpp.c '
/if (tok == TOK___DATE__) {/,/cstrval = buf;/{
  /"%s %2d %d"/s||"Jan  1 1970"|
  /"%02d:%02d:%02d"/s||"00:00:00"|
}
'

# =========================================================
# build:

# to use the present (Minix-2 API) Tiny C Compiler binary (tcc) :
origPATH="$PATH"
PATH=/opt/tinycc/bin:"$PATH"

# the build will need quite a lot of memory
chmem =10000000 /opt/tinycc/bin/tcc

build_the_compiler(){
# relying on PATH (!), to run a different tcc binary later on
  tcc -c \
   -Dstrtof='(float)'strtod \
   -Dstrtold='(long double)'strtod \
   -Dstrtoll=strtol \
   -Dstrtoull=strtoul \
   -DTCC_TARGET_I386 \
   -DTCC_USING_DOUBLE_FOR_LDOUBLE \
   -DCONFIG_TCC_BCHECK=0 \
   -DCONFIG_TCC_BACKTRACE=0 \
   -DONE_SOURCE=0 \
   -DCONFIG_TCC_SEMLOCK=0 \
   -DCONFIG_TCC_STATIC \
   -O2 -I. \
   \
   -DCONFIG_TCC_CRTPREFIX='(getenv("CONFIG_TCC_CRTPREFIX")?getenv("CONFIG_TCC_CRTPREFIX"):"'"$libdest"'")'\
   -DCONFIG_TCC_LIBPATHS='(getenv("CONFIG_TCC_LIBPATHS")?getenv("CONFIG_TCC_LIBPATHS"):"'"$libdest"'")'\
   -DCONFIG_TCC_ELFINTERP='(getenv("CONFIG_TCC_ELFINTERP")?getenv("CONFIG_TCC_ELFINTERP"):"/use-external-dynloader")'\
   \
   "$@" \
   \
   tcc.c tccpp.c tccgen.c tccdbg.c tccelf.c tccasm.c tccrun.c elf2aout.c \
   i386-gen.c i386-link.c i386-asm.c libtcc.c mprotect.c $own_gtod_c

  rm -f tcc
  tcc -o tcc \
  tcc.o tccpp.o tccgen.o tccdbg.o tccelf.o tccasm.o tccrun.o elf2aout.o \
  i386-gen.o i386-link.o i386-asm.o libtcc.o mprotect.o $own_gtod_o

  chmem =10000000 tcc

  ( cd lib
    ../tcc -c libtcc1.c -o libtcc1.o -B.. -I..
    ../tcc -c alloca.S -o alloca.o -B.. -I..
    ../tcc -c alloca-bt.S -o alloca-bt.o -B.. -I..
    ../tcc -c stdatomic.c -o stdatomic.o -B.. -I..
    ../tcc -c dsohandle.c -o dsohandle.o -B.. -I..
    ../tcc -ar rcs ../libtcc1.a libtcc1.o alloca.o \
           alloca-bt.o stdatomic.o dsohandle.o
  )
}

# tweak the prerequisits as dictated by the initial compiler's Minix-2 API:
own_gtod_c=gettimeofday.c
own_gtod_o=gettimeofday.o
fix tcc.h '
/# include <sys\/time\.h>/s||# include "sys_time.h"|
'
build_the_compiler
cp tcc "$bindest"/tcc

# this gave us a "Minix-2-API" binary, but this new compiler binary
# will build Minix-vmd ones

# remake the tweaks for the future proper rebuild(s) :
# restore tcc.h
cp tcc.h. tcc.h
#
own_gtod_c=
own_gtod_o=
fix elf.h '
/"stdint.h"/s||<sys/types.h>|
'
fix elf2aout.c '
/#include <a\.out\.h>/s|<|<mnx/|
'

mkdir "$libdest"
cp -pv libtcc1.a "$libdest"
cp -rpv include/. "$libdest"/include

# begin using the new binary
PATH="$origPATH"

# to be able to produce executables we need libraries
sh -x /mtop/z__tivlib.sh

# replace the compiler with a new one
rebuild_the_compiler(){
  build_the_compiler \
   -I/usr/include/bsdcompat \
   -Duint8_t=u8_t -Dint8_t=i8_t \
   -Duint16_t=u16_t \
   -Duint32_t=u32_t \
   -Duintptr_t=u32_t \
   '-Duint64_t=unsigned long long' '-Dint64_t=long long'
  cp tcc "$bindest"/tcc
}

# because we expect the new compiler binary to be
# functionally equivalent to the original one we used,
# which implies that the new libraries would remain stable,
# let's make one round without rebuilding the libraries
rebuild_the_compiler

# =========================== our rince-and-repeat
stash=/mnt/stash_tcc
mkdir "$stash"
iteration=0
stash_rebuild_compare(){
  iteration="$(expr "$iteration" + 1)"
  mkdir "$stash"/"$iteration"
# no need to check includes, we do not update them
  cp -pv "$libdest"/*.a "$libdest"/*.o "$stash"/"$iteration"
  cp -pv "$bindest"/tcc                "$stash"/"$iteration"
# replace the compiler with a new one
  rebuild_the_compiler
# with the new compiler rebuild the libraries,
# this replaces the libraries in-place:
  sh /mtop/z__tivlib.sh
# now compare the results with the previous ones
  ( set +x
    same=true
    for a in \
             "$bindest"/tcc \
             "$libdest"/*.o \
             "$libdest"/*.a \
    ; do
# list the differing files
      if cmp "$a" "$stash"/"$iteration"/"$(basename "$a")" ; then
        :
      else
        same=false || :
        ls -l "$a" "$stash"/"$iteration"/"$(basename "$a")"
      fi
    done
    if "$same" ; then
      echo "!!!!!!!!!!!! Congratulations, self-hosting works, at iteration $iteration"
      return 0
    fi
    echo "!!!!!!!!!!!! at iteration $iteration not yet there"
    return 1
  ) || return
# || above is meant to avoid triggering an exit due to "set -e"
}

# discovered a bug in ash we are running:
# a non-zero return from a shell function under "set -e"
# always triggers exit from the shell, too bad...
# no way (if we would need repeats) with
#until stash_rebuild_compare; do :; done

# never mind, due to some clever planning above
# the first iteration succeeds, no need to loop
stash_rebuild_compare

# build a showcase executable
cd ..
###cat >b.c <<'____'
###int main(int argc, char **argv){ exit(33); }
###____
cat >thw.c <<'____'
#include <stdio.h>
int main(int argc, char **argv){
  printf("hello from TinyCC\n");
  return 0;
}
____
# an example (not usable as-is) how to run without installation
#( set -x
#  cat thw.c
#  CONFIG_TCC_LIBPATHS=.:libc CONFIG_TCC_CRTPREFIX=libc
#  export CONFIG_TCC_LIBPATHS CONFIG_TCC_CRTPREFIX
#  ./tcc -Iinclude -o thw thw.c
#  ./thw
#  : returns "$?"
#)

# the real stuff
( set -x
  which tcc
  tcc -o thw thw.c
  ./thw
  : returns "$?"
)

cat >floattest.c <<'____'
#include <stdio.h>
int f(double d){ return (int)d; }
int main(int argc, char **argv){
  double d1 = 2.02, d2 = 2.03, d3;
  int i1 = 3, i2 = 4, i3;
  i3 = d1;
  system("cat floattest.c");
  printf("%d*%d=%d, %d\n", i1, i2, i1*i2, i3);
  printf("%d*%d=%d, %d, %f\n", i1, i2, i1*i2, i3, 1.17);
  d2 *= d2;
  i3 = f(d1 * d2);
  //i3 = d1 + d2;
  d3 = d1 + d2;
  ++i2;
  printf("%d*%d=%d, %d, %f*%f=%f, %f\n", i1, i2, i1*i2, i3, d1, d2, d1*d2, 1.17);
  printf("%d*%d=%d, %d, %g*%g=%g, %g\n", i1, i2, i1*i2, i3, d1, d2, d1*d2, d2);
  printf("%d*%d=%d, %d %g %g\n", i1, i2, i1*i2, i3, d3, d2);
  printf("%d*%d=%d, %d %g %g\n", i1, i2, i1*i2, i3, 1.01, 1.02);
  fflush(stdout);
  return 0;
}
____

tcc -o floattest floattest.c
./floattest
tcc -version

## debug
#exit 1

cd /
umount /dev/hd2

exit
