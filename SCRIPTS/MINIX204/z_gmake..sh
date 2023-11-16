#!bourne sh
# to be run by a Bourne-compatible shell
#
# under Minix-2
# use Tiny C Compiler alternatively ACK C compiler
# to build GNU make
#
# 3 arguments:
#   disk image to use (half-disk image is ok)
#   the number of dd (512 byte) blocks in half the disk (aka KiB of the disk)
#   hardware emulation command line, as for y_run.sh

# v.0.3 2023-03-04 an
# v.0.2 2023-03-01 an
# v.0.1 2023-02-26 an

set -e

[ "$#" = 3 ]
diskimg="$1"; shift
blocks="$1"; shift
hw="$1"; shift

. "$S"/z_.sh

# for some consistency in naming
tag=gmake
tver=3.79.1

lastbl="$(expr "$blocks" - 1)"

cd "$B"

make_mydata()(
  [ -d MYDATA_TMP ] && find MYDATA_TMP -type d | xargs chmod u+w
  rm -rf MYDATA_TMP
  mkdir MYDATA_TMP
  cd MYDATA_TMP
  sed '
/@---LASTBL---@/s||'"$lastbl"'|g
/@---TAG---@/s||'"$tag"'|g
/@---TVER---@/s||'"$tver"'|g
  ' > rc <<'____'
#!bourne sh
( set -e
# we accept that a file "rc" (a copy of this one) will be created in /
# for no purpose, for the convenience to directly use full paths in the
# archive instead of moving the data around afterwards and without
# putting absolute paths into the archive
  cd /
# without 'o' tar (at least Minix-2 tar) "restores" totally irrelevant uid/gid data
  compress -d </dev/c0d0p1 | tar xvof -
  ( set -x
    rm rc
    sh /mtop/z__@---TAG---@.sh @---TVER---@ || >/Trouble ) 2>&1 | tee @---TAG---@Log00
  [ ! -f /Trouble ]
# an error return from the script above
# will get to /bin/sh below,
# we are here means success
  rm -rf /mtop
  tar cvf - boot minix bin lib usr opt etc *[lL]og* | compress > /dev/c0d0p1
  sync
  sleep 5
# tell the outside world that it is time to kill the emulator,
# in the last block of the unused space past the root fs partition
#
# (of course, _if_ the emulator flushes the emulated disk to the storage)
  for a in 1 2 3 4 5 6 7 8; do for b in 1 2 3 4 5 6 7 8; do
      echo DONEDON
  done; done | dd seek=@---LASTBL---@ of=/dev/c0d0
  echo "==== DONE ===="
) || (
echo "BAAAAAAAAAAAAAAAAAAAAAAAAD"
)
/bin/sh
exit
____
  mkdir mtop
  cp "$S"/z__"$tag".sh mtop
  ( cd mtop
# recompress with compress
    gzip -d <"$A"/SOURCES/GNU/make-"$tver".tar.gz | compress >gmake.TAZ
  )
  tar cf - rc mtop | compress || :
)

# if we were given a half-disk image, let us fill it out
dd if=/dev/zero seek="$blocks" count="$blocks" of="$diskimg"

# put in our data
make_mydata | dd seek="$blocks" conv=notrunc of="$diskimg"

echo "============== $(date)"
sh "$S"/y_run.sh "$diskimg" "$blocks" "$diskimg" "$hw"
echo "============== $(date)"

exit
