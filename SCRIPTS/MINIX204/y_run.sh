#!bourne sh
# Start target OS and wait for completion
#
# 4 arguments:
#  1. origin disk image file name
#  2. half disk dd (i.e. 512-byte) blocks number (==KiB whole disk)
#  3. destination disk image file name, can be equal to the origin
#  4. hardware emulation command line taking disk image file as an
#     additional single argument, like 'qemu-system-i386 -hda'
#     or a single '-' for (manual) hardware handling
#
# v.0.2 2023-02-11 an
# v.0.1 2023-02-08 an

set -e

[ "$#" = 4 ]
origin="$1"; shift
blocks="$1"; shift
target="$1"; shift
hw="$1"; shift

lastbl="$(expr "$blocks" - 1)"

case "$hw" in
(-)
  case "$target" in
  ("$origin") ;;
  (*) rm -f "$target" ;;
  esac
  echo "\
*** MANUAL INTERACTION NEEDED:
- copy the '$origin' file to a hard disk of at least ${blocks}KiB
- boot from it on a i386- and pre-efi bios-capable hardware
- wait until it says that it is 'DONE' and starts a shell
- copy the first ${blocks}KiB of the disk to '$target'
- when all of the above is done, press Enter
:::"
  read b
# some kind of safety net, only helps if target != origin:
  while [ ! -s "$target" ]; do
    echo "\
*** ${target} still not present or empty,
*** plese follow the earlier given instructions and then press Enter
:::"
    read b
  done
  ;;
(*)
  case "$target" in
  ("$origin") ;;
  (*) cp "$origin" "$target" ;;
  esac
  dd if=/dev/zero count=1 seek="$lastbl" of="$target" conv=notrunc
  eval "$hw"' '"$target"' </dev/null >/dev/tty 2>&1 & pid="$!"'
  ( set +e
    status=1
# wait for the "finish"-sign from the native run
    while [ "$(dd if="$target" skip="$lastbl" count=1 2>/dev/null | wc -l)" -ne 64 ] && kill -0 "$pid" ; do
      sleep 15
    done
    kill "$pid" && status=0
# bochs does not take a sudden death gracefully,
# we have to clean up
    sleep 1
    rm -f "$target".lock
    exit "$status"
  )
  ;;
esac

exit
