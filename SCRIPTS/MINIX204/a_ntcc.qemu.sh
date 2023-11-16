#!bourne sh

# by an own build of recent Tiny C Compiler (x86_64)

tools="
[            [
ar           ar
cat          cat
chmod        chmod
cp           cp
dd           dd
diff         diff
expr         expr
find         find
gzip         gzip
hostcc       /scratch/ntcc
install      install
ln           ln
ls           ls
mkdir        mkdir
printf       printf
rm           rm
sh           sh
sha256sum    sha256sum
sort         sort
tar          tar
xargs        xargs
"
export tools

S="$A"/SCRIPTS/MINIX204
export S

# this does among others 'cd "$B"' :
. "$S"/z_.sh || exit

# use pentium, to correspond to the lowest available cpu model in Bochs
hw='qemu-system-i386 -m 64M -cpu pentium-v1 -enable-kvm -hda'

( ( set -e
  set -x
  sh "$S"/z_tools.sh
# ----------------------- build a crosscompiler and other cross-utils
  sh "$S"/z_xack.gcc.sh
# ----------------------- crosscompile the kernel
  sh "$S"/z_kernel.sh
# ----------------------- crosscompile ash
  sh "$S"/z_ash.sh
# ----------------------- crosscompile the native compiler
  sh "$S"/z_nativeack.sh
# ----------------------- let the resulting cross-built toochain
#                         rebuild itself and whole target OS natively
# ======================= create reproducible: MINIX2       Minix-2 file hierarchy
  sh "$S"/z_hello.sh   \
                       hd0 102400 16 32 MINIX2 "$hw"
# ======================= create reproducible: minix2_ref_0 bootable Minix-2 disk
# ----------------------- create               minix2_0     bootable Minix-2 half-disk
  sh "$S"/z_ref.sh     \
                       MINIX2 minix2_ref_0 102400 16 32 minix2_0 "$hw"
) || >Trouble ) 2>&1 | tee -a a_Log

[ -f Trouble ] && exit 1

exit 0
