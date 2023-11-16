#!bourne sh
# rebuilding Tiny C Compiler by itself under Minix-vmd
#
# v.0.6 2023-03-02
# v.0.5 2023-03-01
# v.0.4 2023-02-26
# v.0.3 2023-02-14
# v.0.2 2023-02-09
# v.0.1 2023-02-04

set -e

set -x

tver="$1"; shift
tnam=tinycc

# we will encounter files with names of exactly 14 bytes
# which is the file system's limit, thus a workaround:
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

# the TinyCC source archive is expected
# to be present in /mtop

# let us use hd2 as the work space

mkfs -t 2f /dev/hd2
mkdir -p /mnt
mount /dev/hd2 /mnt
cd /mnt
compress -d < /mtop/"$tnam".TAZ | tar xf -
# free disk space
rm /mtop/"$tnam".TAZ

compress -d < /mtop/SYS.TAZ | tar xf - \
                              src/lib \
                              src/fs \
                              || :

# free disk space
rm /mtop/SYS.TAZ

# it is a certain tcc version which we handle
cd /mnt/tinycc-"$tver"

# ==============================================
# Minix-specific TinyCC adjustments:

# ----------------------------------------------------------
# add some needed files

cat >sys_mman.h <<'____'
#define PROT_READ      1
#define PROT_WRITE     2
#define PROT_EXEC      4
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

cat >mprotect.c <<'____'
#include <sys/types.h>
int mprotect (void *a, size_t b, int c) {
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

#ifndef _ANSI_H
#include <ansi.h>
#endif

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

_PROTOTYPE( int __setjmp, (jmp_buf env, int savemask)                   );
_PROTOTYPE( void __longjmp, (jmp_buf env, int val)                      );

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
/# include <sys\/time\.h>/s||# include "sys_time.h"|
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
#define CONFIG_TCCDIR "/opt/tinycc/lib"
#define CONFIG_USR_INCLUDE "/opt/mnx2/include"
#define TCC_VERSION "git-${tver}-2_minixvmd"
#define GCC_MAJOR 0
#define GCC_MINOR 0
#define CC_NAME CC_tinycc
#define TCC_GENERATE_AOUT
____

# ==============================================
# TinyCC-specific Minix adjustments
# shall have been done earlier, adding
# /usr/include/stdint.h

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

# to use the previously built TinyCC (as tcc)
PATH=/opt/tinycc/bin:"$PATH"

# the build will need quite a lot of memory
chmem =10000000 /opt/tinycc/bin/tcc

build_the_compiler(){
# rebuild the compiler and the libraries once again
# (we have already patched everything, just compile and make libs)

# using the full path, to make it apparent which "tcc" this is:
  /opt/tinycc/bin/tcc -c \
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
   -DCONFIG_TCC_CRTPREFIX='(getenv("CONFIG_TCC_CRTPREFIX")?getenv("CONFIG_TCC_CRTPREFIX"):"/opt/tinycc/lib")'\
   -DCONFIG_TCC_LIBPATHS='(getenv("CONFIG_TCC_LIBPATHS")?getenv("CONFIG_TCC_LIBPATHS"):"/opt/tinycc/lib")'\
   -DCONFIG_TCC_ELFINTERP='(getenv("CONFIG_TCC_ELFINTERP")?getenv("CONFIG_TCC_ELFINTERP"):"/use-external-dynloader")'\
   \
   tcc.c tccpp.c tccgen.c tccdbg.c tccelf.c tccasm.c tccrun.c elf2aout.c \
   i386-gen.c i386-link.c i386-asm.c libtcc.c mprotect.c gettimeofday.c

  rm -f tcc
  /opt/tinycc/bin/tcc -o tcc \
  tcc.o tccpp.o tccgen.o tccdbg.o tccelf.o tccasm.o tccrun.o elf2aout.o \
  i386-gen.o i386-link.o i386-asm.o libtcc.o mprotect.o gettimeofday.o

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

build_the_compiler

# to be able to produce executables we need a C library,
# let us rebuild it and compare to the one we built last time

mkdir libc
cd libc

for a in \
ansi ip math other posix stdio i386/int64 regex end \
; do cp -rp /mnt/src/lib/"$a" "$(basename "$a")" ; done

cp -v /mnt/src/lib/fphook/fphook.c math

( cd other && fix configfile.c '
/^#include <stdlib\.h>/s||/* & */|
' )

# we undo the unnecessary translation layer,
# applying a hack to collect the list of the names to redefine:
( for a in */_*.c; do
    printf '%s\n' "-D$(basename ${a} .c)=$(expr ${a} : '.*/.\(.*\)..$')"
  done
  printf '%s\n' "-D_sbrk=sbrk"
) >un_underscores
# just for the record (and troubleshooting) :
cat un_underscores

# our undercore-related change triggers interaction with the macros
# in termios.h which coincide with the function names, work around:
for a in get set ; do for b in i o ; do
  fix posix/_cf"$a""$b"speed.c '
/^#include <termios\.h>/a\
#undef cf'"$a""$b"speed'
  '
done; done

# some extra adjustments to make the library compatible with tcc
fix ansi/sigmisc.c '
/_sigprocmask(int, sigset_t/s||_sigprocmask(int, const sigset_t|
'

# build it

for a in *; do
  [ -d "$a" ] || continue
  ( cd "$a" || exit
# remove the undesirable _* redefinitions from the concerned files
    for a in *.c ; do
      case "$a" in *'*'*) break ;; esac
      if awk '$1=="#define"&&"_"$2==$3{print; exit 0}END{exit 1}' "$a" ; then
        fix "$a" '
/#define[ '"$(printf '\t')"']*\([_a-zA-Z0-9][_a-zA-Z0-9]*\)[ '"$(printf '\t')"']*_\1/s|^|//|
        '
      fi
    done
#
    for a in *.c ; do
      case "$a" in *'*'*) break ;; esac
# needed in posix/ , harmless otherwise
      case "$a" in _sigsetjmp.c) continue ;; esac
#
# needed in regex/ , harmless otherwise
      case "$a" in engine.c) continue ;; esac
#
      ../../tcc -c "$a" \
       -I../../include \
       -I/mnt/src \
       -I/mnt/src/lib/other \
       -D_POSIX_SOURCE \
       -D_SETJMP_SAVES_REGS=1 \
       @../un_underscores
    done
  )
done

cd math

cat > frexp.s <<'____'
.globl  _frexp
.text
_frexp:
        pushl   %ebp
        movl    %esp, %ebp
        pushl   %ebx
        pushl   12(%ebp)
        pushl   8(%ebp)
        movl    %esp, %eax
        addl    $-4, %eax
        pushl   %eax
        call    .fef8
        movl    16(%ebp), %eax
        popl    (%eax)
        fldl    (%esp)
        popl    %eax
        popl    %edx
        popl    %ebx
        leave
        ret
.fef8:
// this could be simpler, if only the
// fxtract instruction was emulated properly
        movl    %sp, %ebx
        movl    12(%ebx), %eax
        andl    $0x7ff00000, %eax
        je      1f                         // zero exponent
        shrl    $20, %eax
        subl    $1022, %eax
        movl    %eax, %cx                  // exponent in cx
        movl    12(%ebx), %eax
        andl    $0x800fffff, %eax
        orl     $0x3fe00000, %eax          // load -1 exponent
        movl    8(%ebx), %dx
        movl    4(%ebx), %ebx
        movl    %dx, 4(%ebx)
        movl    %eax, 8(%ebx)
        movl    %cx, (%ebx)
        ret
1:                                         // we get here on zero exp
        movl    12(%ebx), %eax
        andl    $0xfffff, %eax
        orl     8(%ebx), %eax
        jne     1f                         // zero result
        movl    4(%ebx), %ebx
        movl    %eax, (%ebx)
        movl    %eax, 4(%ebx)
        movl    %eax, 8(%ebx)
        ret
1:                                         // otherwise unnormalized number
        movl    12(%ebx), %cx
        andl    $0x800fffff, %cx
        movl    %cx, %dx
        andl    $0x80000000, %cx
        movl    $-1021, %eax
2:
        testl   $0x100000, %dx
        jne     1f
        decl    %eax
        shll    $1, 8(%ebx)
        rcll    $1, %dx
        orl     %cx, %dx
        jmp     2b
1:
        andl    $0x800fffff, %dx
        orl     $0x3fe00000, %dx           // load -1 exponent
        movl    8(%ebx), %cx
        movl    4(%ebx), %ebx
        movl    %eax, (%ebx)
        movl    %dx, 8(%ebx)
        movl    %cx, 4(%ebx)
        ret
____
cat > modf.s <<'____'
.globl  _modf
.text
_modf:
        pushl   %ebp
        movl    %esp, %ebp
        pushl   %ebx
        pushl   12(%ebp)
        pushl   8(%ebp)
        pushl   $1
        pushl   $4
        call    .cif8
        movl    %esp, %eax
        pushl   %eax
        call    .fif8
        popl    %ecx
        movl    16(%ebp), %edx
        popl    %ecx
        popl    %ebx
        movl    %ecx, 0(%edx)
        movl    %ebx, 4(%edx)
        fldl    (%esp)
        popl    %eax
        popl    %edx
        popl    %ebx
        leave
        ret
.cif8:
        movl    %sp, %ebx
        fildl   8(%ebx)
        fstpl   4(%ebx)
        wait
        ret
.fif8:
        movl    %sp, %ebx
        fldl    8(%ebx)
        fmull   16(%ebx)             // multiply
        fld     %st                  // and copy result
        ftst                         // test sign; handle negative separately
        fstsw   %eax
        wait
        sahf                         // result of test in condition codes
        jb      1f
        frndint                      // this one rounds (?)
//      fcom    st(1)                // compare with original; if <=, then OK
.byte   0xd8
.byte   0xd1
        fstsw   %eax
        wait
        sahf
        jbe     2f
        fisubs  one                  // else subtract 1
        jmp     2f
1:                                   // here, negative case
        frndint                      // this one rounds (?)
//      fcom    st(1)                // compare with original; if >=, then OK
.byte   0xd8
.byte   0xd1
        fstsw   %eax
        wait
        sahf
        jae     2f
        fiadds  one                  // else add 1
2:
//      fsub    st(1),st             // subtract integer part
.byte   0xdc
.byte   0xe9
        movl    4(%ebx), %ebx
        fstpl   (%ebx)
        fstpl   8(%ebx)
        wait
        ret
.data
one:
.short  1
____

for a in *.s ; do ../../tcc -c "$a" ; done
cd ..

### libsyscall is nothing more than a redirection layer,
### not needed, the corresponding C routines in posix
### will be used directly

### [i386/]misc is propably redundant for our purposes, skip it;
### it seems it would be needed for kernel builds or alike

for a in int64 end ; do
  ( cd "$a" &&
    mkdir ACK
    for a in *.s ; do
      [ -f ACK/"$a" ] || cp -pv "$a" ACK/"$a"
      ../../tcc -E -I../../include - < ACK/"$a" |
        sed '/\.sect.*\.end/d' |
        /usr/lib/asmconv ack gnu | sed '1d;/^#/d' >"$a"
      ../../tcc -c "$a" || break
    done
  )
done

/usr/lib/asmconv ack gnu /mnt/src/lib/i386/rts/__sigreturn.s |
 sed '1d;/^#/d;/[^_]__sigreturn/s|__|_|' > __sigreturn.s
../tcc -c __sigreturn.s
mv __sigreturn.o other
/usr/lib/asmconv ack gnu /mnt/src/lib/i386/rts/_sendrec.s | sed '1d;/^#/d' > _sendrec.s
../tcc -c _sendrec.s
mv _sendrec.o other
/usr/lib/asmconv ack gnu /mnt/src/lib/i386/rts/brksize.s | sed '1d;/^#/d' > brksize.s
../tcc -c brksize.s
mv brksize.o other

/usr/lib/asmconv ack gnu /mnt/src/lib/i386/rts/crtso.s |
 sed '1d;/^#/d;/crtso/s||_start|;/lcomm/{H;s|[^_]*_|_|;s|,.*|:|p;x;s|.*|.long 0|;}' > crtso.s
# we want to initialize the FPU; besides this
# something like the following should (?) have been done
# in privileged mode by the kernel:
#        .data1  0x0F,0x20,0xC0          ! mov   %eax, %cr0
#        and     %ax, $65531             ! 65535-4==0xfffb, clear bit EM (2^2=4) to indicate presence of FPU
#        or      %ax, $32                ! 32==0x20, set bit NE (2^5=32) to turn off MSDOS compat mode
#        .data1  0x0F,0x22,0xC0          ! mov   %cr0, %eax

# 58331 == .data1 0xDB,0xE3 ! fninit
fix crtso.s '
/call.*_main/i\
\        .word   58331
'
../tcc -c crtso.s

# we need also some other assembler-only functions:
cat >setjmp.s <<'____'
.globl ___setjmp
___setjmp:

        movl    4(%esp), %eax
        movl    %ebx, (%eax)
        movl    %esi, 4(%eax)
        movl    %edi, 8(%eax)
        movl    %ebp, 12(%eax)
        leal    4(%esp), %ecx
        movl    %ecx, 16(%eax)
        movl    (%esp), %ecx
        movl    %ecx, 20(%eax)

        cmpl    $0, 8(%esp)
        je      .dontsavemask
        movl    $1, 24(%eax)
        leal    28(%eax), %ecx
        pushl   %ecx
        call    ___newsigset
        popl    %ecx
        xorl    %eax, %eax
        ret
.dontsavemask:
        movl    $0, 24(%eax)
        xorl    %eax, %eax
        ret

.globl ___longjmp
___longjmp:

        movl    4(%esp), %eax
        cmpl    $0, 24(%eax)
        je      .masknotsaved
        leal    28(%eax), %ecx
        pushl   %ecx
        call    ___oldsigset
        popl    %ecx

.masknotsaved:
        movl    4(%esp), %ecx
        movl    8(%esp), %eax

        movl    (%ecx), %ebx
        movl    4(%ecx), %esi
        movl    8(%ecx), %edi
        movl    12(%ecx), %ebp
        movl    16(%ecx), %esp
        movl    20(%ecx), %edx
        jmp     *%edx
____
../tcc -c setjmp.s

# tcc -ar does not seem to work for iterative archive creation,
# only as one-shot
# but fortunately it takes a list file as well as a command line
>olist
for a in * ; do [ -d "$a" ] || continue; case "$a" in end) continue ;; esac; ls "$a"/*.o >>olist ; done
echo setjmp.o >>olist
../tcc -ar rcs libc.a @olist

../tcc -ar rcs libend.a end/*.o

# try to build an executable
cd ..
###cat >b.c <<'____'
###int main(int argc, char **argv){ exit(33); }
###____
cat >thw.c <<'____'
#include <stdio.h>
int main(int argc, char **argv){
  printf("hello from self-rebuilt TinyCC\n");
  return 0;
}
____
( set -x
  cat thw.c
  CONFIG_TCC_LIBPATHS=.:libc CONFIG_TCC_CRTPREFIX=libc
  export CONFIG_TCC_LIBPATHS CONFIG_TCC_CRTPREFIX
  ./tcc -Iinclude -o thw thw.c
  ./thw
  : returns "$?"
)
# this is already there, but keeping code for reference:
mkdir -p /opt/tinycc/lib \
         /opt/tinycc/bin

install_and_compare(){
  previous="$1"; shift
  mv /opt/tinycc/lib /opt/tinycc/lib."$previous"
  mkdir /opt/tinycc/lib
  for a in \
           libc/crtso.o libtcc1.a libc/libc.a libc/libend.a \
  ; do
    ( set -x; cp -pv "$a" /opt/tinycc/lib/"$(basename "$a")" )
  done
  mkdir /opt/tinycc/lib/include
  cp -pv include/* /opt/tinycc/lib/include
  mv /opt/tinycc/bin/tcc /opt/tinycc/bin/tcc."$previous"
  cp -pv tcc /opt/tinycc/bin
  ( cd /opt/tinycc
    set +x
    same=true
    for a in $(cd lib; find * -type f | sort); do
# list the differing files
      if cmp lib/"$a" lib."$previous"/"$a" ; then
        :
      else
        same=false || :
        ls -l lib/"$a" lib."$previous"/"$a"
      fi
    done
    if cmp bin/tcc bin/tcc."$previous" ; then
      :
    else
      same=false || :
      ls -l bin/tcc bin/tcc."$previous"
    fi
    if "$same" ; then
      echo "!!!!!!!!!!!! Congratulations, self-hosting works"
    else
      echo "!!!!!!!!!!!! not yet there"
    fi
  )
}

install_and_compare 1st
# the libs differ, which does not yet mean much

build_the_compiler

rebuild_the_libraries(){
  cd libc
  rm *.o */*.o

  for a in *; do
    [ -d "$a" ] || continue
    ( cd "$a" || exit
      for a in *.c ; do
        case "$a" in *'*'*) break ;; esac
# needed in posix/ , harmless otherwise
        case "$a" in _sigsetjmp.c) continue ;; esac
#
# needed in regex/ , harmless otherwise
        case "$a" in engine.c) continue ;; esac
#
        ../../tcc -c "$a" \
         -I../../include \
         -I/mnt/src \
         -I/mnt/src/lib/other \
         -D_POSIX_SOURCE \
         -D_SETJMP_SAVES_REGS=1 \
         @../un_underscores
      done
    )
  done
  cd math
  for a in *.s ; do ../../tcc -c "$a" ; done
  cd ..
  for a in int64 end ; do
    ( cd "$a" &&
      for a in *.s ; do
        ../../tcc -c "$a"
      done
    )
  done
  ../tcc -c __sigreturn.s
  mv __sigreturn.o other
  ../tcc -c _sendrec.s
  mv _sendrec.o other
  ../tcc -c brksize.s
  mv brksize.o other
  ../tcc -c crtso.s
  ../tcc -c setjmp.s

  rm libc.a libend.a
  ../tcc -ar rcs libc.a @olist
  ../tcc -ar rcs libend.a end/*.o

  cd ..
}

rebuild_the_libraries

# the compiler is still linked against the old
# libraries, thus the following fails
install_and_compare 2nd

# rince and repeat

build_the_compiler
rebuild_the_libraries
install_and_compare 3rd

# test the installed instance
which tcc
tcc -o ttt thw.c
./ttt

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

# debug:
############/usr/bin/ash </dev/console >/dev/console 2>&1

# clean up the intermediate versions
( cd /opt/tinycc; rm -rf bin/tcc.* lib.* )

cd /
umount /dev/hd2

exit
