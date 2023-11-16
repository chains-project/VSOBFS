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
# ----------------------- build GNU make
# ----------------------- (re)create           hd0           bootable Minix-2 half-disk
# ======================= create reproducible: GMAKE         Minix-2 file hierarchy
###  cp min2tin_0 hd0
  cp minix2_0 hd0

###  sh "$S"/z_gmake..sh \
###                      hd0 102400 tinycc "$hw"
###  sh "$S"/z_gmake..sh \
###                      hd0 102400 ack "$hw"
###  sh "$S"/z_gmake.sh  \
###                      hd0 102400 tinycc GMAKE_TIN "$hw"
  sh "$S"/z_gmake.sh  \
                      hd0 102400 ack GMAKE_ACK "$hw"

) || >Trouble ) 2>&1 | tee -a d_Log

[ -f Trouble ] && exit 1

exit 0
