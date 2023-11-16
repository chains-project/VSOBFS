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

# this does among others 'cd "$B"' :
. "$S"/z_.sh || exit

cat >hostcc <<'____'
#/bin/sh
exec clang "$@"
exit
____
chmod +x hostcc

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
# ----------------------- create               minixvmd_0     bootable Minix-vmd half-disk
  sh "$S"/z_ref.sh    \
                      MINIXVMD minixvmd_ref_0 131072 minixvmd_0 "$hw"
# ----------------------- build the TenDRA C/C++ compiler
# ======================= create reproducible: TENDRA         Minix-vmd file hierarchy
  cp minixvmd_0 hd0
  sh "$S"/z_tendra.sh \
                      hd0 131072 TENDRA "$hw"
# ======================= create reproducible: minvten_ref_0  bootable Minix-vmd disk
# ----------------------- create               minvten_0      bootable Minix-vmd half-disk
  sh "$S"/z_ref.sh    \
                      TENDRA minvten_ref_0 131072 minvten_0 "$hw"
# ----------------------- build the Tiny C compiler
# ======================= create reproducible: TINYCC0        Minix-vmd file hierarchy
  cp minvten_0 hd0
  sh "$S"/z_tinycc.sh \
                      hd0 131072 TINYCC0 "$hw"
# ======================= create reproducible: minvti0_ref_0  bootable Minix-vmd disk
# ----------------------- create               minvti0_0      bootable Minix-vmd half-disk
  sh "$S"/z_ref.sh    \
                      TINYCC0 minvti0_ref_0 131072 minvti0_0 "$hw"
# ----------------------- self-rebuild the Tiny C compiler until it becomes stable
# ======================= create reproducible: TINYCC1        Minix-vmd file hierarchy
  cp minvti0_0 hd0
  sh "$S"/z_tinyre.sh \
                      hd0 131072 TINYCC1 "$hw"
# ======================= create reproducible: minvti1_ref_0  bootable Minix-vmd disk
# ----------------------- create               minvti1_0      bootable Minix-vmd half-disk
  sh "$S"/z_ref.sh    \
                      TINYCC1 minvti1_ref_0 131072 minvti1_0 "$hw"
# ----------------------- build the Tiny C Compiler with Minix-vmd libraries
# ----------------------- recreate             hd0            bootable Minix-vmd half-disk
# ======================= create reproducible: TINYCC         Minix-vmd file hierarchy
  cp minvti1_0 hd0
  sh "$S"/z_tinycv.sh \
                      hd0 131072 TINYCC "$hw"
# ======================= create reproducible: minvtin_ref_0  bootable Minix-vmd disk
# ----------------------- create               minvtin_0      bootable Minix-vmd half-disk
  sh "$S"/z_ref.sh    \
                      TINYCC minvtin_ref_0 131072 minvtin_0 "$hw"

) || >Trouble ) 2>&1 | tee -a k_Log

[ -f Trouble ] && exit 1

exit 0
