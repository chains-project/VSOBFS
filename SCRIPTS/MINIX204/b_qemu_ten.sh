#!bourne sh

tools="
[            [
cat          cat
chmod        chmod
cp           cp
dd           dd
diff         diff
expr         expr
find         find
gzip         gzip
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
# ----------------------- build the TenDRA C/C++ compiler
# ----------------------- (re)create           hd0           bootable Minix-2 half-disk
# ======================= create reproducible: TENDRA        Minix-2 file hierarchy
  cp minix2_0 hd0
  sh "$S"/z_tendra.sh \
                      hd0 102400 TENDRA "$hw"
# ======================= create reproducible: min2ten_ref_0 bootable Minix-2 disk
# ----------------------- create               min2ten_0     bootable Minix-2 half-disk
  sh "$S"/z_ref.sh    \
                      TENDRA min2ten_ref_0 102400 16 32 min2ten_0 "$hw"
) || >Trouble ) 2>&1 | tee -a b_Log

[ -f Trouble ] && exit 1

exit 0
