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
hostcc       clang
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
hw='-'

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
# ----------------------- build the TenDRA C/C++ compiler
# ----------------------- (re)create           hd0           bootable Minix-2 half-disk
# ======================= create reproducible: TENDRA        Minix-2 file hierarchy
  cp minix2_0 hd0
  sh "$S"/z_tendra.sh \
                      hd0 102400 TENDRA "$hw"
#-# ======================= create reproducible: min2ten_ref_0 bootable Minix-2 disk
#-# ----------------------- create               min2ten_0     bootable Minix-2 half-disk
#-  sh "$S"/z_ref.sh    \
#-                      TENDRA min2ten_ref_0 102400 16 32 min2ten_0 "$hw"
# ----------------------- build the Tiny C compiler
# ----------------------- (re)create           hd0           bootable Minix-2 half-disk
# ======================= create reproducible: TINYCC0       Minix-2 file hierarchy
#-  cp min2ten_0 hd0
  sh "$S"/z_tinycc.sh \
                      hd0 102400 TINYCC0 "$hw"
#-# ======================= create reproducible: min2ti0_ref_0 bootable Minix-2 disk
#-# ----------------------- create               min2ti0_0     bootable Minix-2 half-disk
#-  sh "$S"/z_ref.sh    \
#-                      TINYCC0 min2ti0_ref_0 102400 16 32 min2ti0_0 "$hw"
# ----------------------- self-rebuild the Tiny C compiler until it becomes stable
# ----------------------- (re)create           hd0           bootable Minix-2 half-disk
# ======================= create reproducible: TINYCC        Minix-2 file hierarchy
#-  cp min2ti0_0 hd0
  sh "$S"/z_tinyre.sh \
                      hd0 102400 TINYCC "$hw"
# ======================= create reproducible: min2tin_ref_0 bootable Minix-2 disk
# ----------------------- create               min2tin_0     bootable Minix-2 half-disk
  sh "$S"/z_ref.sh    \
                      TINYCC min2tin_ref_0 102400 16 32 min2tin_0 "$hw"

) || >Trouble ) 2>&1 | tee -a p_Log

[ -f Trouble ] && exit 1

exit 0
