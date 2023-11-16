#!bourne sh
# to be run by a Bourne-compatible shell
#
# Create a reproducible bootable disk image
# and its pre-run directly usable (half-)disk instance
#
# 5 arguments:
#   pre-prepared directory with full file data
#   the name of the resulting reproducible disk image
#   the number of dd (512 byte) blocks in half the disk (aka KiB of the disk)
#   the name of the pre-run directly usable (half-)disk image
#   hardware emulation command line, as for y_run.sh
#
# v.0.4 2023-02-26 an
# v.0.3 2023-02-25 an
# v.0.2 2023-02-17 an
# v.0.1 2023-02-12 an

set -e

[ "$#" = 5 ]
tdir="$1"; shift
target="$1"; shift
blocks="$1"; shift
prerun="$1"; shift
hw="$1"; shift

. "$S"/z_.sh

lastbl="$(expr "$blocks" - 1)"

# to be reproducible, we need the same edparams arguments
# for all hardware, both virtual and real, thus we insert
# a delay to make it possible to change the parameters
# on real hardware where manual handling is necessary in any case
edparamsarg='rootdev=hd1;processor=386;main(){delay 5000;boot};save'

# =============== make a reproducible disk image

# note, the /minix directory will initially remain empty,
# because the system image is too large to be but there
make_reprootfs(){
  cd "$B"
  [ -d REPROOT_FS ] && find REPROOT_FS -type d | xargs chmod u+w && rm -rf REPROOT_FS
  mkdir REPROOT_FS \
        REPROOT_FS/bin \
        REPROOT_FS/dev \
        REPROOT_FS/etc \
        REPROOT_FS/minix \
        REPROOT_FS/root \
        REPROOT_FS/sbin \
        REPROOT_FS/tmp \
        REPROOT_FS/usr \
        REPROOT_FS/usr/bin \
        REPROOT_FS/usr/lib \
        REPROOT_FS/usr/tmp \


  chmod 1777 REPROOT_FS/tmp REPROOT_FS/usr/tmp
  for a in \
sbin/init \
bin/sh \
bin/mount \
usr/bin/tar \
  ; do
    cp "$tdir"/"$a" REPROOT_FS/"$a"
  done
# arrange safe replacement of /etc/rc
  cat > REPROOT_FS/etc/rc <<'____'
#!/bin/sh
exec /bin/sh /etc/rc.1st
____
  sed '
/@---LASTBL---@/s||'"$lastbl"'|g
  ' > REPROOT_FS/etc/rc.1st <<'____'
#!/bin/sh
umask 022
PATH=/bin:/usr/bin:/sbin:/usr/sbin
TERM="minix"
export PATH TERM
exec </dev/console >/dev/console 2>&1
mount -v -o remount,rw /dev/hd1 /
( set -e
  cd /
# unpack the whole of the system
  echo "unpacking the system..."
  tar xf /dev/hd2
  echo "done"
  chmod 1777 /tmp /usr/tmp
# MAKEDEV depends on the contents of /etc (passwd and group)
# that's why we would not try it early
  ( cd /dev ; MAKEDEV std )
# keep this script, for reference and troubleshooting
###  rm -f /etc/rc.1st
  sync
  sleep 2
# tell the outside world that it is time to kill the emulator,
# in the last block of the unused space past the root fs partition
#
# (of course, _if_ the emulator flushes the emulated disk to the storage)
  for a in 1 2 3 4 5 6 7 8; do for b in 1 2 3 4 5 6 7 8; do
      echo DONEDON
  done; done | dd seek=@---LASTBL---@ of=/dev/hd0
  echo "==== DONE ===="
# in case the outside world does not care, we would like
# to proceed with a standard startup, hopefully without
# losing the "DONE" message present on the console,
# but first give the outside world a chance, to avoid
# accidentally damaging an active file system;
# we assume that outside polling is done (at least)
# each 15 seconds
  sleep 20
  exec /bin/sh /etc/rc_std start
) || (
echo "BAAAAAAAAAAAAAAAAAAAAAAAAD"
)
# for troubleshooting:
/bin/sh
exit
____
}

make_repdatapart(){
  rm -f repdatapart
# we do not want to replace /boot because its block numbers
# have been patched into the boot block;
# no need to supply the other pre-arranged files either
# (boot is put there by y_bootable.sh below)
  cp -rp "$tdir" rep_tmp
  ( set -x
    for a in . bin usr/bin ; do
      chmod u+w rep_tmp/"$a"
    done
    for a in boot bin/sh usr/bin/tar ; do
# some can be absent, otherwise are write-protected,
# -f to avoid questions from rm
      rm -f rep_tmp/"$a"
    done
  )
  ( cd rep_tmp
    find . -type f -o -type l | LANG=C sort | xargs sltar c
  ) >repdatapart
  find rep_tmp -type d | xargs chmod u+w
  rm -rf rep_tmp
}

make_reprootfs
make_repdatapart
# figure out the latest versioned system image under minix/
# and indicate for y_bootable.sh that the image is too big
# to be put into the file system via mkfs
sysimage="$(LANG=C; ls "$tdir"/minix/* | while :; do if read a; then b="$a"; else echo "$b"; break; fi; done)"
sh -x "$S"/y_bootable.sh \
                         REPROOT_FS \
                         "$tdir"/usr/mdec/masterboot \
                         "$tdir"/usr/mdec/bootblock \
                         "$tdir"/usr/mdec/boot \
                         +"$sysimage" \
                         repdatapart \
                         "$target" "$blocks" \
                         "$edparamsarg"

# this is to be reproducible:
hash="$(sha256sum < "$target")"
echo "%%% ${hash} ${target}"

# we will need a directly usable pre-run instance of this

echo "============== $(date)"
sh "$S"/y_run.sh "$target" "$blocks" "$prerun" "$hw"
echo "============== $(date)"

# we only need the first half
dd if="$prerun" count="$blocks" of="$prerun".half
# it can happen to be owned by root and non-writable,
# avoid qestions from "mv":
rm -f "$prerun"
#
mv "$prerun".half "$prerun"

# the pre-run instance is regrettably not reproducible by itself

exit
