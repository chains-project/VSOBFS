#!bourne sh
# to be run by a Bourne-compatible shell
#
# build a bootable disk image
#
# v.0.7 2023-02-12 an
# v.0.6 2023-02-11 an
# v.0.5 2023-02-07 an
# v.0.4 2023-02-05 an
# v.0.3 2022-09-24 an
# v.0.2 2022-08-08 an
#
# 11 arguments:
#   name of a pre-populated root-fs directory (without /boot and /minix)
#   master boot block file
#   minix boot block file
#   boot program file
#   system image file (with prepended '+' if it is too big for mkfs)
#   data partition file name
#   disk image name
#   number of dd (512 byte) blocks in half the disk (aka KiB of the disk)
#   heads on the disk
#   sectors on the disk track
#   edparams argument
#
# NOTE qemu allows max 16 heads, secs are max 63

# we create an extra partition as a means to transfer files in and out

set -e

[ "$#" = 11 ]
rootfs="$1"; shift
masterboot="$1"; shift
bootblock="$1"; shift
bootprog="$1"; shift
sysimage="$1"; shift
datapt="$1"; shift
disk="$1"; shift
blocks="$1"; shift
heads="$1"; shift
secs="$1"; shift
edparamsarg="$1"; shift

. "$S"/z_.sh

lastbl="$(expr "$blocks" - 1)"

dd if=/dev/zero bs=512 count=1 of=mbr

# recalculate the disk size to partiton sizes

start2="$(expr "$blocks" / "$heads" / "$secs")"
end1="$(expr "$start2" - 1)"
end2="$(expr "$start2" + "$end1")"

fdisk -h"$heads" -s"$secs" mbr <<____
c
1
0
$end1
y
c
2
$start2
$end2
n
w
____

# create a corresponding "almost half disk" file system
# which could be booted
# NOTE the file system should be _smaller_ than the partition
# so that "installboot" _can_ put the boot code and the system image
# after the filesystem end
# e.g. mkproto shall get "-b49152" argument for a 50MiB partition,
# reserving about 1MB at the end for the kernel image
# (note that we use the very last block of the partition
# for other purposes)

fssize="$(expr "$blocks" / 2 - 2048)"

# this can be always done:
cp "$bootprog" "$rootfs"/boot

# only if it is small enough to go through mkfs:
case "$sysimage" in
(+*) ;;
(*) cp "$sysimage" "$rootfs"/minix ;;
esac

mkproto -b"$fssize" -d'  ' "$rootfs" >rootfs_proto
# we need some special files,
# they must be provided separately from mkproto
fix rootfs_proto '
/^  dev /a\
\    console  c--600 0 0 4 0\
\    c0d0  b--600 0 0 3 0\
\    c0d0p0  b--600 0 0 3 1\
\    c0d0p1  b--600 0 0 3 2
'

rm -f root_fs
mkfs root_fs rootfs_proto

case "$sysimage" in
(+*)
# image is too big for mkfs, put it outside the file system
  sysimage="$(expr "$sysimage" : '.\(.*\)')"
# add the boot block, the boot monitor code and the bootable image
# to the file system (just past its end)
  installboot -d root_fs "$bootblock" "$bootprog" "$sysimage"
  ;;
(*)
# this uses the boot data inside the file system:
  installboot -d root_fs "$bootblock" boot
  ;;
esac

edparams root_fs "$edparamsarg"

# combine the file system with the mbr and a data partition into a disk image,
# zero-fill possibly incomplete partitions up to the exact size
#
# data partition contents file size is not necessarily block-aligned,
# there is a chance that the dd reading the pipe becomes starved
# and gets a partial block, that's why we check and fill at the end;
# partial blocks can not happen with root_fs because mkfs write block-aligned
>> "$datapt"
( cat mbr       root_fs /dev/zero | dd count="$blocks"
  cat "$datapt"         /dev/zero | dd count="$blocks"
) >"$disk"
# the most portable (?) way to get the file size:
got="$(wc -c "$disk" | ( read a b; printf '%s\n' "$a" ) )"
#
# expr returns 1 when the result is 0
toadd="$(expr "$blocks" '*' 512 '*' 2 - "$got")" &&
 dd bs=1 if=/dev/zero count="$toadd" >>"$disk"

# give the disk image the master boot code
installboot -m "$disk" "$masterboot"

exit
