#!/bin/sh
#
# build Minix-vmd libraries with/for Tiny C Compiler
#
# v.0.3 2023-03-03
# v.0.2 2023-03-02
# v.0.1 2023-03-01

set -e

there=/mnt/src
dest=/usr/lib/tcc

cd "$there"

rm -rf libsbuild
mkdir libsbuild
for a in \
/usr/lib/cc/i386/end.a \
/usr/lib/cc/i386/libbsd.a \
/usr/lib/cc/i386/libc.a \
/usr/lib/cc/i386/libedit.a \
/usr/lib/cc/i386/libm.a \
/usr/lib/cc/i386/libmalloc.a \
/usr/lib/cc/i386/libnofp.a \
/usr/lib/cc/i386/libsys.a \
/usr/lib/cc/i386/liby.a \
; do
  mkdir libsbuild/"$(basename "$a" .a)"
done

cc(){
  case "$1" in
  -mi386) shift ;;
  -c.a)
    : cc "$@"
    shift
    while [ "$#" -gt 1 ]; do
      case "$1" in
      *.a) 
        a="$there"/libsbuild/"$(basename "$1" .a)"
        shift
        cp -v "$@" "$a"
        return
        ;;
      esac
      shift
    done
    exit 1
    ;;
  esac
  case "$*" in
  *.s)
# BE CAREFUL, at reruns do not repeat tweaking
    a="$(while [ "$#" -gt 1 ]; do shift ; done; printf '%s\n' "$1")"
    [ -f ACK/"$a" ] || {
      mkdir -p ACK
      [ -f ACK/"$a" ] || cp -pv "$a" ACK/"$a"
# remove all occurences of confusing characters in the comments
      sed '
:again
s|\(!.*\)['"'"'`]|\1|
t again
          ' ACK/"$a" |
       tcc -E -I. - |
       sed '/\.sect.*\.end/d' |
       /usr/lib/asmconv ack gnu |
       sed '1d;/^#/d' >"$a"
# special cases:
      case "$a" in
# --------- we want to add fp init
      crtso.ack.s)
# 58331 == .data1 0xDB,0xE3 ! fninit
        sed \
            '
/crtso/s||_start|
/lcomm/{H;s|[^_]*_|_|;s|,.*|:|p;x;s|.*|.long 0|;}
/call.*_main/i\
\        .word   58331
          ' \
            <crtso.ack.s >s.s
        mv s.s crtso.ack.s
        ;;
# --------- uses mnemonics not known to the compiler
      catchsig.ack.s)
# 96 = 0x60 ! pushal
# 97 = 0x61 ! popal
        sed \
            's|pushal|.byte 96|;s|popal|.byte 97|' \
            <catchsig.ack.s >s.s
        mv s.s catchsig.ack.s
        ;;
# --------- uses mnemonics not known to the compiler
      memset.ack.s)
        sed \
            '/sall/s||shl|' \
            <memset.ack.s >s.s
        mv s.s memset.ack.s
        ;;
      esac
    }
# a special case: (also at reruns)
# --------- the startup file, not a part of a library
    case "$a" in
    crtso.ack.s)
      tcc -c crtso.ack.s
      mv crtso.ack.o "$dest"/crtso.o
      return
      ;;
    esac
    ;;
  esac
# (using the knowledge that there is no whitespace in the args,
# we could do array operations properly but that is not needed here) :
  cmdline=''
  case "$*" in
  *' -wo '*) cmdline="$(expr "$*" : '\(.*\) -wo .*') $(expr "$*" : '.* -wo \(.*\)')" ;;
  *)         cmdline="$*" ;;
  esac
  tcc $cmdline
}

( cd lib
  ( cd ack/mach/i386
# not relevant for using this compiler:
#    ( cd head
#cc -mi386  -c -I. em_head.s
#cc -c.a -o /usr/lib/cc/i386/libc.a *.o
#rm *.o
#    )
#    ( cd libem
#cc -mi386  -c em_adf4.s
#cc -mi386  -c em_adf8.s
#cc -mi386  -c em_adi.s
#cc -mi386  -c em_and.s
#cc -mi386  -c em_blm.s
#cc -mi386  -c em_cff4.s
#cc -mi386  -c em_cff8.s
#cc -mi386  -c em_cfi.s
#cc -mi386  -c em_cfu.s
#cc -mi386  -c em_cif4.s
#cc -mi386  -c em_cif8.s
#cc -mi386  -c em_cii.s
#cc -mi386  -c em_cmf4.s
#cc -mi386  -c em_cmf8.s
#cc -mi386  -c em_cms.s
#cc -mi386  -c em_com.s
#cc -mi386  -c em_csa4.s
#cc -mi386  -c em_csb4.s
#cc -mi386  -c em_cuf4.s
#cc -mi386  -c em_cuf8.s
#cc -mi386  -c em_cuu.s
#cc -mi386  -c em_dup.s
#cc -mi386  -c em_dvf4.s
#cc -mi386  -c em_dvf8.s
#cc -mi386  -c em_dvi.s
#cc -mi386  -c em_dvu.s
#cc -mi386  -c em_error.s
#cc -mi386  -c em_exg.s
#cc -mi386  -c em_fat.s
#cc -mi386  -c em_fef4.s
#cc -mi386  -c em_fef8.s
#cc -mi386  -c em_fif4.s
#cc -mi386  -c em_fif8.s
#cc -mi386  -c em_fp8087.s
#cc -mi386  -c em_gto.s
#cc -mi386  -c em_iaar.s
#cc -mi386  -c em_ilar.s
#cc -mi386  -c em_inn.s
#cc -mi386  -c em_ior.s
#cc -mi386  -c em_isar.s
#cc -mi386  -c em_lar4.s
#cc -mi386  -c em_loi.s
#cc -mi386  -c em_mlf4.s
#cc -mi386  -c em_mlf8.s
#cc -mi386  -c em_mli.s
#cc -mi386  -c em_mon.s
#cc -mi386  -c em_ngf4.s
#cc -mi386  -c em_ngf8.s
#cc -mi386  -c em_ngi.s
#cc -mi386  -c em_nop.s
#cc -mi386  -c em_print.s
#cc -mi386  -c em_rck.s
#cc -mi386  -c em_rmi.s
#cc -mi386  -c em_rmu.s
#cc -mi386  -c em_rol.s
#cc -mi386  -c em_ror.s
#cc -mi386  -c em_sar4.s
#cc -mi386  -c em_sbf4.s
#cc -mi386  -c em_sbf8.s
#cc -mi386  -c em_sbi.s
#cc -mi386  -c em_set.s
#cc -mi386  -c em_sli.s
#cc -mi386  -c em_sri.s
#cc -mi386  -c em_sti.s
#cc -mi386  -c em_stop.s
#cc -mi386  -c em_strhp.s
#cc -mi386  -c em_trp.s
#cc -mi386  -c em_unknown.s
#cc -mi386  -c em_xor.s
#cc -c.a -o /usr/lib/cc/i386/libc.a *.o
#rm *.o
#    )
    ( cd libend
cc -mi386  -c _end.s
cc -mi386  -c edata.s
cc -mi386  -c end.s
cc -mi386  -c etext.s
cc -c.a -o /usr/lib/cc/i386/end.a *.o
rm *.o
    )
  )
# not relevant for using this compiler:
#  ( cd ack/mach/generic/libfp
#cc -mi386 -I../../i386/libem -c add_ext.c
#cc -mi386 -I../../i386/libem -c adder.c
#cc -mi386 -I../../i386/libem -c soft_adf4.c
#cc -mi386 -I../../i386/libem -c soft_adf8.c
#cc -mi386 -I../../i386/libem -c soft_cff4.c
#cc -mi386 -I../../i386/libem -c soft_cff8.c
#cc -mi386 -I../../i386/libem -c soft_cfi.c
#cc -mi386 -I../../i386/libem -c soft_cfu.c
#cc -mi386 -I../../i386/libem -c soft_cif4.c
#cc -mi386 -I../../i386/libem -c soft_cif8.c
#cc -mi386 -I../../i386/libem -c soft_cmf4.c
#cc -mi386 -I../../i386/libem -c soft_cmf8.c
#cc -mi386 -I../../i386/libem -c compact.c
#cc -mi386 -I../../i386/libem -c soft_cuf4.c
#cc -mi386 -I../../i386/libem -c soft_cuf8.c
#cc -mi386 -I../../i386/libem -c div_ext.c
#cc -mi386 -I../../i386/libem -c soft_dvf4.c
#cc -mi386 -I../../i386/libem -c soft_dvf8.c
#cc -mi386 -I../../i386/libem -c extend.c
#cc -mi386 -I../../i386/libem -c soft_fef4.c
#cc -mi386 -I../../i386/libem -c soft_fef8.c
#cc -mi386 -I../../i386/libem -c soft_fif4.c
#cc -mi386 -I../../i386/libem -c soft_fif8.c
#cc -mi386 -I../../i386/libem -c fptrp.e
#cc -mi386 -I../../i386/libem -c soft_mlf4.c
#cc -mi386 -I../../i386/libem -c soft_mlf8.c
#cc -mi386 -I../../i386/libem -c mul_ext.c
#cc -mi386 -I../../i386/libem -c soft_ngf4.c
#cc -mi386 -I../../i386/libem -c soft_ngf8.c
#cc -mi386 -I../../i386/libem -c nrm_ext.c
#cc -mi386 -I../../i386/libem -c soft_sbf4.c
#cc -mi386 -I../../i386/libem -c soft_sbf8.c
#cc -mi386 -I../../i386/libem -c sft_ext.c
#cc -mi386 -I../../i386/libem -c shifter.c
#cc -mi386 -I../../i386/libem -c sub_ext.c
#cc -mi386 -I../../i386/libem -c soft_zrf4.c
#cc -mi386 -I../../i386/libem -c soft_zrf8.c
#cc -mi386 -I../../i386/libem -c zrf_ext.c
#cc -c.a -o /usr/lib/cc/i386/libc.a *.o
#rm *.o
#  )
  ( cd ack/setjmp
cc -mi386 -O9 -D_POSIX_SOURCE -c _siglongjmp.c
# this compiler does it differently:
#cc -mi386 -O9 -D_POSIX_SOURCE -c setjmp.e
#
cc -mi386 -O9 -D_POSIX_SOURCE -c sigmisc.c
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
  )
  ( cd mach/minix.i386
    ( cd head
cc -mi386  -c -o /usr/lib/cc/i386/crtso.o crtso.ack.s
    )
    ( cd libsys
cc -mi386  -c __sigreturn.ack.s
cc -mi386  -c _receive.ack.s
cc -mi386  -c _send.ack.s
cc -mi386  -c _sendrec.ack.s
cc -mi386  -c brksize.ack.s
cc -mi386  -c catchsig.ack.s
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
    )
    ( cd stubs
cc -mi386  -c _exit.ack.s
cc -mi386  -c access.ack.s
cc -mi386  -c alarm.ack.s
cc -mi386  -c brk.ack.s
cc -mi386  -c cfgetispeed.ack.s
cc -mi386  -c cfgetospeed.ack.s
cc -mi386  -c cfsetispeed.ack.s
cc -mi386  -c cfsetospeed.ack.s
cc -mi386  -c chdir.ack.s
cc -mi386  -c chmod.ack.s
cc -mi386  -c chown.ack.s
cc -mi386  -c chroot.ack.s
cc -mi386  -c close.ack.s
cc -mi386  -c closedir.ack.s
cc -mi386  -c creat.ack.s
cc -mi386  -c dup.ack.s
cc -mi386  -c dup2.ack.s
cc -mi386  -c endgrent.ack.s
cc -mi386  -c endpwent.ack.s
cc -mi386  -c execl.ack.s
cc -mi386  -c execle.ack.s
cc -mi386  -c execlp.ack.s
cc -mi386  -c execv.ack.s
cc -mi386  -c execve.ack.s
cc -mi386  -c execvp.ack.s
cc -mi386  -c fcancel.ack.s
cc -mi386  -c fcntl.ack.s
cc -mi386  -c fork.ack.s
cc -mi386  -c fstat.ack.s
cc -mi386  -c fwait.ack.s
cc -mi386  -c getcwd.ack.s
cc -mi386  -c getegid.ack.s
cc -mi386  -c geteuid.ack.s
cc -mi386  -c getgid.ack.s
cc -mi386  -c getgrent.ack.s
cc -mi386  -c getgrgid.ack.s
cc -mi386  -c getgrnam.ack.s
cc -mi386  -c getgroups.ack.s
cc -mi386  -c getpgrp.ack.s
cc -mi386  -c getpid.ack.s
cc -mi386  -c getppid.ack.s
cc -mi386  -c getpwent.ack.s
cc -mi386  -c getpwnam.ack.s
cc -mi386  -c getpwuid.ack.s
cc -mi386  -c getuid.ack.s
cc -mi386  -c ioctl.ack.s
cc -mi386  -c isatty.ack.s
cc -mi386  -c kill.ack.s
cc -mi386  -c link.ack.s
cc -mi386  -c lseek.ack.s
cc -mi386  -c lstat.ack.s
cc -mi386  -c mkdir.ack.s
cc -mi386  -c mkfifo.ack.s
cc -mi386  -c mknod.ack.s
cc -mi386  -c mount.ack.s
cc -mi386  -c nice.ack.s
cc -mi386  -c open.ack.s
cc -mi386  -c opendir.ack.s
cc -mi386  -c pathconf.ack.s
cc -mi386  -c pause.ack.s
cc -mi386  -c pipe.ack.s
cc -mi386  -c read.ack.s
cc -mi386  -c readdir.ack.s
cc -mi386  -c readlink.ack.s
cc -mi386  -c reboot.ack.s
cc -mi386  -c rename.ack.s
cc -mi386  -c rewinddir.ack.s
cc -mi386  -c rmdir.ack.s
cc -mi386  -c sbrk.ack.s
cc -mi386  -c seekdir.ack.s
cc -mi386  -c setgid.ack.s
cc -mi386  -c setgrent.ack.s
cc -mi386  -c setgrfile.ack.s
cc -mi386  -c setgroups.ack.s
cc -mi386  -c setpgid.ack.s
cc -mi386  -c setpwent.ack.s
cc -mi386  -c setpwfile.ack.s
cc -mi386  -c setsid.ack.s
cc -mi386  -c setuid.ack.s
cc -mi386  -c sigaction.ack.s
cc -mi386  -c sigaddset.ack.s
cc -mi386  -c sigdelset.ack.s
cc -mi386  -c sigemptyset.ack.s
cc -mi386  -c sigfillset.ack.s
cc -mi386  -c sigismember.ack.s
cc -mi386  -c siglongjmp.ack.s
cc -mi386  -c signal.ack.s
cc -mi386  -c sigpending.ack.s
cc -mi386  -c sigprocmask.ack.s
cc -mi386  -c sigreturn.ack.s
cc -mi386  -c sigsuspend.ack.s
cc -mi386  -c sleep.ack.s
cc -mi386  -c stat.ack.s
cc -mi386  -c stime.ack.s
cc -mi386  -c svrctl.ack.s
cc -mi386  -c swapoff.ack.s
cc -mi386  -c symlink.ack.s
cc -mi386  -c sync.ack.s
cc -mi386  -c sysenv.ack.s
cc -mi386  -c system.ack.s
cc -mi386  -c sysuname.ack.s
cc -mi386  -c sysutime.ack.s
cc -mi386  -c tcdrain.ack.s
cc -mi386  -c tcflow.ack.s
cc -mi386  -c tcflush.ack.s
cc -mi386  -c tcgetattr.ack.s
cc -mi386  -c tcgetpgrp.ack.s
cc -mi386  -c tcsendbreak.ack.s
cc -mi386  -c tcsetattr.ack.s
cc -mi386  -c tcsetpgrp.ack.s
cc -mi386  -c time.ack.s
cc -mi386  -c times.ack.s
cc -mi386  -c umask.ack.s
cc -mi386  -c umount.ack.s
cc -mi386  -c uname.ack.s
cc -mi386  -c unlink.ack.s
cc -mi386  -c utime.ack.s
cc -mi386  -c wait.ack.s
cc -mi386  -c waitpid.ack.s
cc -mi386  -c write.ack.s
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
    )
  )
  ( cd mach/i386
    ( cd int64
cc -mi386  -c add64.ack.s
cc -mi386  -c add64u.ack.s
cc -mi386  -c cmp64.ack.s
cc -mi386  -c cv64u.ack.s
cc -mi386  -c cvu64.ack.s
cc -mi386  -c diff64.ack.s
cc -mi386  -c div64u.ack.s
cc -mi386  -c ex64.ack.s
cc -mi386  -c make64.ack.s
cc -mi386  -c mul64u.ack.s
cc -mi386  -c sub64.ack.s
cc -mi386  -c sub64u.ack.s
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
    )
    ( cd misc
cc -mi386  -c alloca.ack.s
cc -mi386  -c get_bp.ack.s
# only relevant for boot code and the kernel, not our targets:
#cc -mi386  -c getprocessor.ack.s
#
cc -mi386  -c i486alignck.ack.s
cc -mi386  -c iolib.ack.s
cc -mi386  -c oneC_sum.ack.s
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
    )
    ( cd string
cc -mi386  -c _memmove.ack.s
cc -mi386  -c _strncat.ack.s
cc -mi386  -c _strncmp.ack.s
cc -mi386  -c _strncpy.ack.s
cc -mi386  -c _strnlen.ack.s
cc -mi386  -c bcmp.ack.s
cc -mi386  -c bcopy.ack.s
cc -mi386  -c bzero.ack.s
cc -mi386  -c index.ack.s
cc -mi386  -c memchr.ack.s
cc -mi386  -c memcmp.ack.s
cc -mi386  -c memcpy.ack.s
cc -mi386  -c memmove.ack.s
cc -mi386  -c memset.ack.s
cc -mi386  -c rindex.ack.s
cc -mi386  -c strcat.ack.s
cc -mi386  -c strchr.ack.s
cc -mi386  -c strcmp.ack.s
cc -mi386  -c strcpy.ack.s
cc -mi386  -c strlen.ack.s
cc -mi386  -c strncat.ack.s
cc -mi386  -c strncmp.ack.s
cc -mi386  -c strncpy.ack.s
cc -mi386  -c strnlen.ack.s
cc -mi386  -c strrchr.ack.s
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
    )
  )
  ( cd ip
cc -mi386 -O9 -D_MINIX -c ether_line.c
cc -mi386 -O9 -D_MINIX -c ethera2n.c
cc -mi386 -O9 -D_MINIX -c ethere2a.c
cc -mi386 -O9 -D_MINIX -c etherh2n.c
cc -mi386 -O9 -D_MINIX -c ethern2h.c
cc -mi386 -O9 -D_MINIX -c getdomainname.c
cc -mi386 -O9 -D_MINIX -c gethostname.c
cc -mi386 -O9 -D_MINIX -c hton.c
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
  )
  ( cd misc
cc -mi386 -O9 -D_MINIX -c crypt.c
cc -mi386 -O9 -D_MINIX -c environ.c
cc -mi386 -O9 -D_MINIX -c -w hugeval.c
cc -mi386 -O9 -D_MINIX -c memcspn.c
cc -mi386 -O9 -D_MINIX -c paramvalue.c
cc -mi386 -O9 -D_MINIX -c queryparam.c
cc -mi386 -O9 -D_MINIX -c -wo read_nlist.c
cc -mi386 -O9 -D_MINIX -c ttyslot.c
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
cc -mi386 -O9 -D_MINIX -c -DDEBUG malloc.c
cc -c.a -o /usr/lib/cc/i386/libmalloc.a malloc.o
rm malloc.o
cc -mi386 -O9 -D_MINIX -c -DKERNEL -o kmalloc.o malloc.c
cc -c.a -o /usr/lib/cc/i386/libsys.a *.o
rm *.o
    ( cd sdbm
cc -mi386 -O2 -D_MINIX -DSDBM -DDUFF -DNULLKEY -c hash.c
cc -mi386 -O2 -D_MINIX -DSDBM -DDUFF -DNULLKEY -c sdbm.c
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
    )
  )
  ( cd os/minix
    ( cd ansi
cc -mi386 -O9 -c clock.c
cc -mi386 -O9 -c fabs.c
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
    )
    ( cd other
cc -mi386 -O9 -D_MINIX -c _seekdir.c
cc -mi386 -O9 -D_MINIX -c -I../../../../sys fslib.c
cc -mi386 -O9 -D_MINIX -c ftruncate.c
cc -mi386 -O9 -D_MINIX -c getmntany.c
cc -mi386 -O9 -D_MINIX -c getmntent.c
cc -mi386 -O9 -D_MINIX -c getpass.c
cc -mi386 -O9 -D_MINIX -c gettimeofday.c
cc -mi386 -O9 -D_MINIX -c getttyent.c
cc -mi386 -O9 -D_MINIX -c hasmntopt.c
cc -mi386 -O9 -D_MINIX -c initgroups.c
cc -mi386 -O9 -D_MINIX -c itoa.c
cc -mi386 -O9 -D_MINIX -c lockf.c
cc -mi386 -O9 -D_MINIX -c -D_OLD_NLIST nlist.c
cc -mi386 -O9 -D_MINIX -c putmntent.c
cc -mi386 -O9 -D_MINIX -c regexp.c
cc -mi386 -O9 -D_MINIX -c regsub.c
cc -mi386 -O9 -D_MINIX -c stderr.c
cc -mi386 -O9 -D_MINIX -c telldir.c
cc -mi386 -O9 -D_MINIX -c u_sleep.c
cc -mi386 -O9 -D_MINIX -c usleep.c
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
cc -mi386 -O9 -D_MINIX -c printk.c
cc -c.a -o /usr/lib/cc/i386/libsys.a *.o
rm *.o
    )
    ( cd posix
cc -mi386 -O9 -D_MINIX -c _cfgetispeed.c
cc -mi386 -O9 -D_MINIX -c _cfgetospeed.c
cc -mi386 -O9 -D_MINIX -c _cfsetispeed.c
cc -mi386 -O9 -D_MINIX -c _cfsetospeed.c
cc -mi386 -O9 -D_MINIX -c _closedir.c
cc -mi386 -O9 -D_MINIX -c _dup.c
cc -mi386 -O9 -D_MINIX -c _dup2.c
cc -mi386 -O9 -D_MINIX -c _execl.c
cc -mi386 -O9 -D_MINIX -c _execle.c
cc -mi386 -O9 -D_MINIX -c _execlp.c
cc -mi386 -O9 -D_MINIX -c _execv.c
cc -mi386 -O9 -D_MINIX -c _execvp.c
cc -mi386 -O9 -D_MINIX -c _fpathconf.c
cc -mi386 -O9 -D_MINIX -c _getcwd.c
cc -mi386 -O9 -D_MINIX -c _getgrent.c
cc -mi386 -O9 -D_MINIX -c _getpwent.c
cc -mi386 -O9 -D_MINIX -c _isatty.c
cc -mi386 -O9 -D_MINIX -c _opendir.c
cc -mi386 -O9 -D_MINIX -c _pathconf.c
cc -mi386 -O9 -D_MINIX -c _pconf.c
cc -mi386 -O9 -D_MINIX -c _readdir.c
cc -mi386 -O9 -D_MINIX -c _rewinddir.c
cc -mi386 -O9 -D_MINIX -c _sigset.c
cc -mi386 -O9 -D_MINIX -c _sleep.c
cc -mi386 -O9 -D_MINIX -c _system.c
cc -mi386 -O9 -D_MINIX -c _tcdrain.c
cc -mi386 -O9 -D_MINIX -c _tcflow.c
cc -mi386 -O9 -D_MINIX -c _tcflush.c
cc -mi386 -O9 -D_MINIX -c _tcgetattr.c
cc -mi386 -O9 -D_MINIX -c _tcgetpgrp.c
cc -mi386 -O9 -D_MINIX -c _tcsendbreak.c
cc -mi386 -O9 -D_MINIX -c _tcsetattr.c
cc -mi386 -O9 -D_MINIX -c _tcsetpgrp.c
cc -mi386 -O9 -D_MINIX -c _uname.c
cc -mi386 -O9 -D_MINIX -c ctermid.c
cc -mi386 -O9 -D_MINIX -c cuserid.c
cc -mi386 -O9 -D_MINIX -c getlogin.c
cc -mi386 -O9 -D_MINIX -c sysconf.c
cc -mi386 -O9 -D_MINIX -c ttyname.c
cc -mi386 -O9 -D_MINIX -c vectab.c
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
    )
    ( cd syscall
cc -mi386 -O9 -D_MINIX -c __exit.c
cc -mi386 -O9 -D_MINIX -c _access.c
cc -mi386 -O9 -D_MINIX -c _alarm.c
cc -mi386 -O9 -D_MINIX -c _brk.c
cc -mi386 -O9 -D_MINIX -c _chdir.c
cc -mi386 -O9 -D_MINIX -c _chmod.c
cc -mi386 -O9 -D_MINIX -c _chown.c
cc -mi386 -O9 -D_MINIX -c _chroot.c
cc -mi386 -O9 -D_MINIX -c _close.c
cc -mi386 -O9 -D_MINIX -c _creat.c
cc -mi386 -O9 -D_MINIX -c _execve.c
cc -mi386 -O9 -D_MINIX -c _fcancel.c
cc -mi386 -O9 -D_MINIX -c _fcntl.c
cc -mi386 -O9 -D_MINIX -c _fork.c
cc -mi386 -O9 -D_MINIX -c _fstat.c
cc -mi386 -O9 -D_MINIX -c _fwait.c
cc -mi386 -O9 -D_MINIX -c _getegid.c
cc -mi386 -O9 -D_MINIX -c _geteuid.c
cc -mi386 -O9 -D_MINIX -c _getgid.c
cc -mi386 -O9 -D_MINIX -c _getgroups.c
cc -mi386 -O9 -D_MINIX -c _getpgrp.c
cc -mi386 -O9 -D_MINIX -c _getpid.c
cc -mi386 -O9 -D_MINIX -c _getppid.c
cc -mi386 -O9 -D_MINIX -c _getuid.c
cc -mi386 -O9 -D_MINIX -c _ioctl.c
cc -mi386 -O9 -D_MINIX -c _kill.c
cc -mi386 -O9 -D_MINIX -c _link.c
cc -mi386 -O9 -D_MINIX -c _lseek.c
cc -mi386 -O9 -D_MINIX -c _lstat.c
cc -mi386 -O9 -D_MINIX -c _m3_loadname.c
cc -mi386 -O9 -D_MINIX -c _mkdir.c
cc -mi386 -O9 -D_MINIX -c _mkfifo.c
cc -mi386 -O9 -D_MINIX -c _mknod.c
cc -mi386 -O9 -D_MINIX -c _mount.c
cc -mi386 -O9 -D_MINIX -c _nice.c
cc -mi386 -O9 -D_MINIX -c _open.c
cc -mi386 -O9 -D_MINIX -c _pause.c
cc -mi386 -O9 -D_MINIX -c _pipe.c
cc -mi386 -O9 -D_MINIX -c _ptrace.c
cc -mi386 -O9 -D_MINIX -c _read.c
cc -mi386 -O9 -D_MINIX -c _readlink.c
cc -mi386 -O9 -D_MINIX -c _reboot.c
cc -mi386 -O9 -D_MINIX -c _rename.c
cc -mi386 -O9 -D_MINIX -c _rmdir.c
cc -mi386 -O9 -D_MINIX -c _setgid.c
cc -mi386 -O9 -D_MINIX -c _setgroups.c
cc -mi386 -O9 -D_MINIX -c _setpgid.c
cc -mi386 -O9 -D_MINIX -c _setsid.c
cc -mi386 -O9 -D_MINIX -c _setuid.c
cc -mi386 -O9 -D_MINIX -c _sigaction.c
cc -mi386 -O9 -D_MINIX -c _signal.c
cc -mi386 -O9 -D_MINIX -c _sigpending.c
cc -mi386 -O9 -D_MINIX -c _sigprocmask.c
cc -mi386 -O9 -D_MINIX -c _sigreturn.c
cc -mi386 -O9 -D_MINIX -c _sigsuspend.c
cc -mi386 -O9 -D_MINIX -c _stat.c
cc -mi386 -O9 -D_MINIX -c _stime.c
cc -mi386 -O9 -D_MINIX -c _svrctl.c
cc -mi386 -O9 -D_MINIX -c _swapoff.c
cc -mi386 -O9 -D_MINIX -c _symlink.c
cc -mi386 -O9 -D_MINIX -c _sync.c
cc -mi386 -O9 -D_MINIX -c _syscall.c
cc -mi386 -O9 -D_MINIX -c _sysenv.c
cc -mi386 -O9 -D_MINIX -c _sysuname.c
cc -mi386 -O9 -D_MINIX -c _sysutime.c
cc -mi386 -O9 -D_MINIX -c _time.c
cc -mi386 -O9 -D_MINIX -c _times.c
cc -mi386 -O9 -D_MINIX -c _umask.c
cc -mi386 -O9 -D_MINIX -c _umount.c
cc -mi386 -O9 -D_MINIX -c _unlink.c
cc -mi386 -O9 -D_MINIX -c _utime.c
cc -mi386 -O9 -D_MINIX -c _wait.c
cc -mi386 -O9 -D_MINIX -c _waitpid.c
cc -mi386 -O9 -D_MINIX -c _write.c
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
    )
    ( cd syslib
cc -mi386 -O9 -D_MINIX -c _taskcall.c
cc -mi386 -O9 -D_MINIX -c sys_abort.c
cc -mi386 -O9 -D_MINIX -c sys_adj_data.c
cc -mi386 -O9 -D_MINIX -c sys_adj_stack.c
cc -mi386 -O9 -D_MINIX -c sys_copy.c
cc -mi386 -O9 -D_MINIX -c sys_core.c
cc -mi386 -O9 -D_MINIX -c sys_delmap.c
cc -mi386 -O9 -D_MINIX -c sys_dupseg.c
cc -mi386 -O9 -D_MINIX -c sys_exec.c
cc -mi386 -O9 -D_MINIX -c sys_findproc.c
cc -mi386 -O9 -D_MINIX -c sys_fork.c
cc -mi386 -O9 -D_MINIX -c sys_getmap.c
cc -mi386 -O9 -D_MINIX -c sys_getsig.c
cc -mi386 -O9 -D_MINIX -c sys_getsp.c
cc -mi386 -O9 -D_MINIX -c sys_kill.c
cc -mi386 -O9 -D_MINIX -c sys_newmap.c
cc -mi386 -O9 -D_MINIX -c sys_nice.c
cc -mi386 -O9 -D_MINIX -c sys_oldsig.c
cc -mi386 -O9 -D_MINIX -c sys_puts.c
cc -mi386 -O9 -D_MINIX -c sys_sendsig.c
cc -mi386 -O9 -D_MINIX -c sys_sigreturn.c
cc -mi386 -O9 -D_MINIX -c sys_swapoff.c
cc -mi386 -O9 -D_MINIX -c sys_sysctl.c
cc -mi386 -O9 -D_MINIX -c sys_sysenv.c
cc -mi386 -O9 -D_MINIX -c sys_times.c
cc -mi386 -O9 -D_MINIX -c sys_trace.c
cc -mi386 -O9 -D_MINIX -c sys_umap.c
cc -mi386 -O9 -D_MINIX -c sys_vm_lock.c
cc -mi386 -O9 -D_MINIX -c sys_vm_unlock.c
cc -mi386 -O9 -D_MINIX -c sys_xit.c
cc -c.a -o /usr/lib/cc/i386/libsys.a *.o
rm *.o
    )
    ( cd errno
cc -mi386 -O9 -D_MINIX -c errlist.c
cc -mi386 -O9 -D_MINIX -c errno.c
cc -mi386 -O9 -D_MINIX -c strerror.c
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
    )
  )
  ( cd ieee_float
cc -mi386 -O9 -c frexp.c
cc -mi386 -O9 -c isinf.c
cc -mi386 -O9 -c isnan.c
cc -mi386 -O9 -c ldexp.c
cc -mi386 -O9 -c modf.c
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
  )
  ( cd libm
cc -mi386 -O -D_IEEE_LIBM -c e_acos.c
cc -mi386 -O -D_IEEE_LIBM -c e_acosh.c
cc -mi386 -O -D_IEEE_LIBM -c e_asin.c
cc -mi386 -O -D_IEEE_LIBM -c e_atan2.c
cc -mi386 -O -D_IEEE_LIBM -c e_atanh.c
cc -mi386 -O -D_IEEE_LIBM -c e_cosh.c
cc -mi386 -O -D_IEEE_LIBM -c e_exp.c
cc -mi386 -O -D_IEEE_LIBM -c e_fmod.c
cc -mi386 -O -D_IEEE_LIBM -c e_gamma.c
cc -mi386 -O -D_IEEE_LIBM -c e_gamma_r.c
cc -mi386 -O -D_IEEE_LIBM -c e_hypot.c
cc -mi386 -O -D_IEEE_LIBM -c e_j0.c
cc -mi386 -O -D_IEEE_LIBM -c e_j1.c
cc -mi386 -O -D_IEEE_LIBM -c e_jn.c
cc -mi386 -O -D_IEEE_LIBM -c e_lgamma.c
cc -mi386 -O -D_IEEE_LIBM -c e_lgamma_r.c
cc -mi386 -O -D_IEEE_LIBM -c e_log.c
cc -mi386 -O -D_IEEE_LIBM -c e_log10.c
cc -mi386 -O -D_IEEE_LIBM -c e_pow.c
cc -mi386 -O -D_IEEE_LIBM -c e_rem_pio2.c
cc -mi386 -O -D_IEEE_LIBM -c e_remainder.c
cc -mi386 -O -D_IEEE_LIBM -c e_scalb.c
cc -mi386 -O -D_IEEE_LIBM -c e_sinh.c
cc -mi386 -O -D_IEEE_LIBM -c e_sqrt.c
cc -mi386 -O -D_IEEE_LIBM -c k_cos.c
cc -mi386 -O -D_IEEE_LIBM -c k_rem_pio2.c
cc -mi386 -O -D_IEEE_LIBM -c k_sin.c
cc -mi386 -O -D_IEEE_LIBM -c k_standard.c
cc -mi386 -O -D_IEEE_LIBM -c k_tan.c
cc -mi386 -O -D_IEEE_LIBM -c s_asinh.c
cc -mi386 -O -D_IEEE_LIBM -c s_atan.c
cc -mi386 -O -D_IEEE_LIBM -c s_cbrt.c
cc -mi386 -O -D_IEEE_LIBM -c s_ceil.c
cc -mi386 -O -D_IEEE_LIBM -c s_copysign.c
cc -mi386 -O -D_IEEE_LIBM -c s_cos.c
cc -mi386 -O -D_IEEE_LIBM -c s_erf.c
cc -mi386 -O -D_IEEE_LIBM -c s_expm1.c
cc -mi386 -O -D_IEEE_LIBM -c s_fabs.c
cc -mi386 -O -D_IEEE_LIBM -c s_finite.c
cc -mi386 -O -D_IEEE_LIBM -c s_floor.c
cc -mi386 -O -D_IEEE_LIBM -c s_frexp.c
cc -mi386 -O -D_IEEE_LIBM -c s_ilogb.c
cc -mi386 -O -D_IEEE_LIBM -c s_isnan.c
cc -mi386 -O -D_IEEE_LIBM -c s_ldexp.c
cc -mi386 -O -D_IEEE_LIBM -c s_lib_version.c
cc -mi386 -O -D_IEEE_LIBM -c s_log1p.c
cc -mi386 -O -D_IEEE_LIBM -c s_logb.c
cc -mi386 -O -D_IEEE_LIBM -c s_matherr.c
cc -mi386 -O -D_IEEE_LIBM -c s_modf.c
cc -mi386 -O -D_IEEE_LIBM -c s_nextafter.c
cc -mi386 -O -D_IEEE_LIBM -c s_rint.c
cc -mi386 -O -D_IEEE_LIBM -c s_scalbn.c
cc -mi386 -O -D_IEEE_LIBM -c s_signgam.c
cc -mi386 -O -D_IEEE_LIBM -c s_significand.c
cc -mi386 -O -D_IEEE_LIBM -c s_sin.c
cc -mi386 -O -D_IEEE_LIBM -c s_tan.c
cc -mi386 -O -D_IEEE_LIBM -c s_tanh.c
cc -mi386 -O -D_IEEE_LIBM -c w_acos.c
cc -mi386 -O -D_IEEE_LIBM -c w_acosh.c
cc -mi386 -O -D_IEEE_LIBM -c w_asin.c
cc -mi386 -O -D_IEEE_LIBM -c w_atan2.c
cc -mi386 -O -D_IEEE_LIBM -c w_atanh.c
cc -mi386 -O -D_IEEE_LIBM -c w_cosh.c
cc -mi386 -O -D_IEEE_LIBM -c w_exp.c
cc -mi386 -O -D_IEEE_LIBM -c w_fmod.c
cc -mi386 -O -D_IEEE_LIBM -c w_gamma.c
cc -mi386 -O -D_IEEE_LIBM -c w_gamma_r.c
cc -mi386 -O -D_IEEE_LIBM -c w_hypot.c
cc -mi386 -O -D_IEEE_LIBM -c w_j0.c
cc -mi386 -O -D_IEEE_LIBM -c w_j1.c
cc -mi386 -O -D_IEEE_LIBM -c w_jn.c
cc -mi386 -O -D_IEEE_LIBM -c w_lgamma.c
cc -mi386 -O -D_IEEE_LIBM -c w_lgamma_r.c
cc -mi386 -O -D_IEEE_LIBM -c w_log.c
cc -mi386 -O -D_IEEE_LIBM -c w_log10.c
cc -mi386 -O -D_IEEE_LIBM -c w_pow.c
cc -mi386 -O -D_IEEE_LIBM -c w_remainder.c
cc -mi386 -O -D_IEEE_LIBM -c w_scalb.c
cc -mi386 -O -D_IEEE_LIBM -c w_sinh.c
cc -mi386 -O -D_IEEE_LIBM -c w_sqrt.c
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
  )
  ( cd libnbio
cc -mi386 -O9 -c nbio_data.c
cc -mi386 -O9 -c nbio_fdop.c
cc -mi386 -O9 -c nbio_rw.c
cc -mi386 -O9 -c nbio_select.c
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
  )
  ( cd libasyn
cc -mi386 -O9 -c asyn_cancel.c
cc -mi386 -O9 -c asyn_close.c
cc -mi386 -O9 -c asyn_init.c
cc -mi386 -O9 -c asyn_ioctl.c
cc -mi386 -O9 -c asyn_pending.c
cc -mi386 -O9 -c asyn_read.c
cc -mi386 -O9 -c asyn_synch.c
cc -mi386 -O9 -c asyn_wait.c
cc -mi386 -O9 -c asyn_write.c
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
  )
  ( cd curses
cc -mi386 -O9 -D_MINIX -c beep.c
cc -mi386 -O9 -D_MINIX -c charpick.c
cc -mi386 -O9 -D_MINIX -c curs_set.c
cc -mi386 -O9 -D_MINIX -c cursesio.c
cc -mi386 -O9 -D_MINIX -c endwin.c
cc -mi386 -O9 -D_MINIX -c flash.c
cc -mi386 -O9 -D_MINIX -c initscr.c
cc -mi386 -O9 -D_MINIX -c longname.c
cc -mi386 -O9 -D_MINIX -c move.c
cc -mi386 -O9 -D_MINIX -c mvcursor.c
cc -mi386 -O9 -D_MINIX -c newwin.c
cc -mi386 -O9 -D_MINIX -c options.c
cc -mi386 -O9 -D_MINIX -c overlay.c
cc -mi386 -O9 -D_MINIX -c prntscan.c
cc -mi386 -O9 -D_MINIX -c refresh.c
cc -mi386 -O9 -D_MINIX -c scrreg.c
cc -mi386 -O9 -D_MINIX -c setterm.c
cc -mi386 -O9 -D_MINIX -c tabsize.c
cc -mi386 -O9 -D_MINIX -c termmisc.c
cc -mi386 -O9 -D_MINIX -c unctrl.c
cc -mi386 -O9 -D_MINIX -c update.c
cc -mi386 -O9 -D_MINIX -c waddch.c
cc -mi386 -O9 -D_MINIX -c waddstr.c
cc -mi386 -O9 -D_MINIX -c wbox.c
cc -mi386 -O9 -D_MINIX -c wclear.c
cc -mi386 -O9 -D_MINIX -c wclrtobot.c
cc -mi386 -O9 -D_MINIX -c wclrtoeol.c
cc -mi386 -O9 -D_MINIX -c wdelch.c
cc -mi386 -O9 -D_MINIX -c wdeleteln.c
cc -mi386 -O9 -D_MINIX -c werase.c
cc -mi386 -O9 -D_MINIX -c wgetch.c
cc -mi386 -O9 -D_MINIX -c wgetstr.c
cc -mi386 -O9 -D_MINIX -c windel.c
cc -mi386 -O9 -D_MINIX -c winmove.c
cc -mi386 -O9 -D_MINIX -c winsch.c
cc -mi386 -O9 -D_MINIX -c winscrol.c
cc -mi386 -O9 -D_MINIX -c winsertln.c
cc -mi386 -O9 -D_MINIX -c wintouch.c
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
  )
  ( cd editline
cc -mi386 -O9 -D_MINIX -DANSI_ARROWS -DHAVE_STDLIB -DHAVE_TCGETATTR -DHIDE -DUSE_DIRENT \
	  -DHIST_SIZE=100 -DUSE_TERMCAP -DSYS_UNIX -wo -c editline.c
cc -mi386 -O9 -D_MINIX -DANSI_ARROWS -DHAVE_STDLIB -DHAVE_TCGETATTR -DHIDE -DUSE_DIRENT \
	  -DHIST_SIZE=100 -DUSE_TERMCAP -DSYS_UNIX -wo -c complete.c
cc -mi386 -O9 -D_MINIX -DANSI_ARROWS -DHAVE_STDLIB -DHAVE_TCGETATTR -DHIDE -DUSE_DIRENT \
	  -DHIST_SIZE=100 -DUSE_TERMCAP -DSYS_UNIX -wo -c sysunix.c
cc -c.a -o /usr/lib/cc/i386/libedit.a *.o
rm *.o
  )
  ( cd dummy
echo "int __dummy__;" >dummy.c
cc -c dummy.c
cc -c.a -o /usr/lib/cc/i386/libm.a dummy.o
rm dummy.?
  )
)
( cd bsd/lib
  ( cd libc
    ( cd db
      ( cd btree
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c bt_close.c
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c bt_conv.c
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c bt_delete.c
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c bt_get.c
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c bt_open.c
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c bt_overflow.c
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c bt_page.c
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c bt_put.c
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c bt_search.c
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c bt_seq.c
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c bt_split.c
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c bt_stack.c
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c bt_utils.c
cc -c.a -o /usr/lib/cc/i386/libbsd.a *.o
rm *.o
      )
      ( cd db
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c db.c
cc -c.a -o /usr/lib/cc/i386/libbsd.a *.o
rm *.o
      )
      ( cd hash
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c hash.c
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c hash_bigkey.c
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c hash_buf.c
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c hash_func.c
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c hash_log2.c
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c hash_page.c
cc -c.a -o /usr/lib/cc/i386/libbsd.a *.o
rm *.o
      )
      ( cd mpool
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c mpool.c
cc -c.a -o /usr/lib/cc/i386/libbsd.a *.o
rm *.o
      )
      ( cd recno
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c rec_close.c
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c rec_delete.c
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c rec_get.c
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c rec_open.c
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c rec_put.c
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c rec_search.c
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c rec_seq.c
cc -mi386 -O9 -D__DBINTERFACE_PRIVATE -I/usr/include/bsdcompat -c rec_utils.c
cc -c.a -o /usr/lib/cc/i386/libbsd.a *.o
rm *.o
      )
    )
    ( cd gen
cc -mi386 -O9 -I/usr/include/bsdcompat -D_MINIX -c ctime.c
cc -mi386 -O9 -I/usr/include/bsdcompat -D_MINIX -c difftime.c
cc -mi386 -O9 -I/usr/include/bsdcompat -D_MINIX -c getcap.c
cc -mi386 -O9 -I/usr/include/bsdcompat -D_MINIX -c popen.c
cc -mi386 -O9 -I/usr/include/bsdcompat -D_MINIX -c raise.c
cc -mi386 -O9 -I/usr/include/bsdcompat -D_MINIX -c syslog.c
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
cc -mi386 -O9 -I/usr/include/bsdcompat -D_MINIX -c daemon.c
cc -mi386 -O9 -I/usr/include/bsdcompat -D_MINIX -c err.c
cc -c.a -o /usr/lib/cc/i386/libbsd.a *.o
rm *.o
    )
    ( cd i386
      ( cd minix
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c getpagesize.c
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
      )
    )
    ( cd locale
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c ansi.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c asciicase.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c asciictype.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c euc.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c isctype.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c lconv.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c localeconv.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c none.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c rune.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c setlocale.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c setrunelocale.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c table.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c utf2.c
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
    )
    ( cd minix
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c assert.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c getdtablesize.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c writev.c
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c utimes.c
cc -c.a -o /usr/lib/cc/i386/libbsd.a *.o
rm *.o
    )
    ( cd net
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c gethostent.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c gethostnamadr.c -O2
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c getnetbyaddr.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c getnetbyname.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c getnetent.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c getproto.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c getprotoent.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c getprotoname.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c getservbyname.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c getservbyport.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c getservent.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c herror.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c inet_addr.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c inet_network.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c inet_ntoa.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c rcmd.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c res_comp.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c res_init.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c res_mkquery.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c res_query.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c res_send.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c sethostent.c
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c inet_makeaddr.c
cc -c.a -o /usr/lib/cc/i386/libbsd.a *.o
rm *.o
    )
    ( cd regex
cc -mi386 -O9 -I/usr/include/bsdcompat -c regcomp.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c regerror.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c regexec.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c regfree.c
cc -c.a -o /usr/lib/cc/i386/libbsd.a *.o
rm *.o
    )
    ( cd stdio
cc -mi386 -O9 -I/usr/include/bsdcompat -c clrerr.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c fclose.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c fdopen.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c feof.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c ferror.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c fflush.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c fgetc.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c fgetln.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c fgets.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c fileno.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c findfp.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c flags.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c fopen.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c fprintf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c fputc.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c fputs.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c fread.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c freopen.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c fscanf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c fseek.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c ftell.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c fvwrite.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c fwalk.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c fwrite.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c getc.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c getchar.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c getw.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c makebuf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c mktemp.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c perror.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c printf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c putc.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c putchar.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c puts.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c putw.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c refill.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c remove.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c rewind.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c rget.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c scanf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c setbuf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c setvbuf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c snprintf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c sprintf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c sscanf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c stdio.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c -D_MINIX tmpnam.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c ungetc.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c vfprintf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c vfscanf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c vprintf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c vscanf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c vsnprintf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c vsprintf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c vsscanf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c wbuf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c wsetup.c
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
cc -mi386 -O9 -I/usr/include/bsdcompat -c funopen.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c tempnam.c
cc -c.a -o /usr/lib/cc/i386/libbsd.a *.o
rm *.o
cc -mi386 -O9 -I/usr/include/bsdcompat -c fprintf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c fscanf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c printf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c scanf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c snprintf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c sprintf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c sscanf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c -DFLOATING_POINT=0 vfprintf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c -DFLOATING_POINT=0 vfscanf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c vprintf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c vscanf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c vsnprintf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c vsprintf.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c vsscanf.c
cc -c.a -o /usr/lib/cc/i386/libnofp.a *.o
rm *.o
    )
    ( cd stdlib
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c abort.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c abs.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c atexit.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c atof.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c atoi.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c atol.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c bsearch.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c calloc.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c div.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c exit.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c getenv.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c getopt.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c labs.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c ldiv.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c malloc.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c putenv.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c qsort.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c rand.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c random.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c setenv.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c strtod.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c strtol.c
cc -mi386 -O9 -D_MINIX -I/usr/include/bsdcompat -c strtoul.c
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
    )
    ( cd string
cc -mi386 -O9 -I/usr/include/bsdcompat -c ffs.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c memccpy.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c strcasecmp.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c strcoll.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c strcspn.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c strdup.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c strftime.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c strmode.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c strpbrk.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c strsep.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c strspn.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c strstr.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c strtok.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c strxfrm.c
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
    )
  )
  ( cd libterm
cc -mi386 -O9 -I/usr/include/bsdcompat -c termcap.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c tgoto.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c tputs.c
cc -c.a -o /usr/lib/cc/i386/libc.a *.o
rm *.o
  )
  ( cd libutil
cc -mi386 -O9 -I/usr/include/bsdcompat -c login_tty.c
cc -mi386 -O9 -I/usr/include/bsdcompat -c pty.c
cc -c.a -o /usr/lib/cc/i386/libbsd.a *.o
rm *.o
  )
  ( cd liby
cc -mi386 -O9 -wo -c main.c
cc -mi386 -O9 -wo -c yyerror.c
cc -c.a -o /usr/lib/cc/i386/liby.a *.o
rm *.o
  )
)

cd libsbuild

# we use specific startup and setjump implementations
# and need this extra assembler-only function:
# (from the TenDRA Minix-2 port)
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
tcc -c setjmp.s
mv setjmp.o libc
rm setjmp.s

# tcc -ar does not seem to work for iterative archive creation,
# only as one-shot
# but fortunately it takes a list file as well as a command line
# which otherwise could become too long
#
# right now we _only_ have lib-directories here
# so "*" is safe
for a in * ; do
# there should not be anything besides *.o
# but it does not hurt to be robust
  ( cd "$a"
    ls | grep '\.o$' >../olist
    tcc -ar rcs ../"$a".a @../olist
  )
done

mv end.a libend.a

cp -v *.a "$dest"

for a in \
curses \
nbio \
ndbm \
sdbm \
termcap \
; do
  rm -f "$dest"/lib"$a".a
  ln "$dest"/libm.a "$dest"/lib"$a".a
done

ls -li "$dest"
: ==== libraries BUILT ====

## debug:
#exit 1

exit
