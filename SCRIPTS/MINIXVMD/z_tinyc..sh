#!bourne sh
# to be run by a Bourne-compatible shell
#
# under Minix-vmd
# use TenDRA C/C++ compiler
# to build Tiny C Compiler
#
# 3 arguments:
#   disk image to use (half-disk image is ok)
#   the number of dd (512 byte) blocks in half the disk (aka KiB of the disk)
#   hardware emulation command line, as for y_run.sh

# v.0.9 2023-03-03 an
# v.0.8 2023-03-01 an
# v.0.7 2023-02-26 an
# v.0.6 2023-02-25 an
# v.0.5 2023-02-25 an
# v.0.4 2023-02-23 an
# v.0.3 2023-02-15 an
# v.0.2 2023-02-05 an
# v.0.1 2023-02-04 an

set -e

[ "$#" = 3 ]
diskimg="$1"; shift
blocks="$1"; shift
hw="$1"; shift

. "$S"/z_.sh

# for some consistency in naming
tag=tinycc
tver=20a1ebf

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
  compress -d </dev/hd2 | tar xvof -
  ( set -x
    rm rc
    sh /mtop/z__@---TAG---@.sh @---TVER---@ || >/Trouble ) 2>&1 | tee @---TAG---@Log00
  [ ! -f /Trouble ]
# an error return from the script above
# will get to /bin/sh below,
# we are here means success
  rm -rf /mtop
  tar cvf - boot minix bin lib sbin usr opt etc *[lL]og* | compress > /dev/hd2
  sync
  sleep 5
# tell the outside world that it is time to kill the emulator,
# in the last block of the unused space past the root fs partition
#
# (of course, _if_ the emulator flushes the emulated disk to the storage)
  for a in 1 2 3 4 5 6 7 8; do for b in 1 2 3 4 5 6 7 8; do
      echo DONEDON
  done; done | dd seek=@---LASTBL---@ of=/dev/hd0
  echo "==== DONE ===="
) || (
echo "BAAAAAAAAAAAAAAAAAAAAAAAAD"
)
/bin/sh
exit
____
  mkdir mtop
  cp "$S"/z__"$tag".sh mtop
# we will need Minix-2 library sources
  cp "$A"/SOURCES/SYS.TAZ               mtop
  cp "$A"/SOURCES/elf2aout.c.for_tinycc mtop/elf2aout.c
# we have got a file system here with a 14 byte file name limitation
  cp "$A"/PATCHES/patch.tinycc_tendrify mtop/patch.tinycc_t
  cp "$A"/SOURCES/elf.h                 mtop/elf.h
#
  ( cd mtop
# tinycc-archive is not tar but pax, transform into tar:
    gzip -d <"$A"/SOURCES/tinycc-"$tver".tar.gz | tar xf - tinycc-"$tver"
    tar cf - tinycc-"$tver" | compress > tinycc.TAZ
    rm -r tinycc-"$tver"
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

# keep it for reuse/reference/troubleshooting
###rm "$diskimg"

exit
