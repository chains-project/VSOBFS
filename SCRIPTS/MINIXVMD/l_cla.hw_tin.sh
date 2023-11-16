#!bourne sh

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
hostcc       "$B"/hostcc
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

S="$A"/SCRIPTS/MINIXVMD
export S

cat >hostcc <<'____'
#/bin/sh
exec clang "$@"
exit
____
chmod +x hostcc

# this does among others 'cd "$B"' :
. "$S"/z_.sh || exit

# use pentium, to correspond to the lowest available cpu model in Bochs
hw='-'

( ( set -e
  set -x
  sh "$S"/z_tools.sh
# ----------------------- build a crosscompiler and other cross-utils
  sh "$S"/z_xack.cla.sh
# ----------------------- crosscompile the kernel
  sh "$S"/z_kernel.sh
# ----------------------- crosscompile ash
  sh "$S"/z_ash.sh
# ----------------------- crosscompile the native compiler
  sh "$S"/z_nativeack.sh
# ----------------------- let the resulting cross-built toochain
#                         rebuild itself and whole target OS natively
# ======================= create reproducible: MINIXVMD       Minix-vmd file hierarchy
  sh "$S"/z_hello.sh  \
                      hd0 131072 MINIXVMD "$hw"
# ======================= create reproducible: minixvmd_ref_0 bootable Minix-vmd disk
# ----------------------- (re)create           hd0            bootable Minix-vmd half-disk
  sh "$S"/z_ref.sh    \
                      MINIXVMD minixvmd_ref_0 131072 hd0 "$hw"
# ----------------------- build the TenDRA C/C++ compiler
# ----------------------- recreate             hd0            bootable Minix-vmd half-disk
  sh "$S"/z_tendr..sh \
                      hd0 131072 "$hw"
# ----------------------- build the Tiny C compiler
# ----------------------- recreate             hd0            bootable Minix-vmd half-disk
  sh "$S"/z_tinyc..sh \
                      hd0 131072 "$hw"
# ----------------------- self-rebuild the Tiny C compiler until it becomes stable
# ----------------------- recreate             hd0            bootable Minix-vmd half-disk
  sh "$S"/z_tinyr..sh \
                      hd0 131072 "$hw"
# ----------------------- build the Tiny C Compiler with Minix-vmd libraries
# ----------------------- recreate             hd0            bootable Minix-vmd half-disk
# ======================= create reproducible: TINYCC         Minix-vmd file hierarchy
  sh "$S"/z_tinycv.sh \
                      hd0 131072 TINYCC "$hw"
# ======================= create reproducible: minvtin_ref_0  bootable Minix-vmd disk
# ----------------------- create               minvtin_0      bootable Minix-vmd half-disk
  sh "$S"/z_ref.sh    \
                      TINYCC minvtin_ref_0 131072 minvtin_0 "$hw"

) || >Trouble ) 2>&1 | tee -a l_Log

[ -f Trouble ] && exit 1

exit 0
