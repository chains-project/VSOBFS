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
hostcc       pcc
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

# prepare bochs configuration
# (slirp is useful for development, not used during the automated building)
# NOTE bios images paths may have to be adjusted
# WARNING it _must_ be BIOS-bochs-legacy, the only one working with i386
cat > bochs.slirp.conf <<'____'
# slirp config
# The line above is mandatory

hostfwd = tcp:127.0.0.1:2223-:23
____
cat >bochsstartrc <<'____'
c
____
cat >f_runbochs.sh <<'____'
#!/bin/sh
bios="$1"; shift
vgabios="$1"; shift
hd="$1"; shift
sed '
s|@---BIOS---@|'"$bios"'|
s|@---VGABIOS---@|'"$vgabios"'|
s|@---HD---@|'"$B"/"$hd"'|
' > bochsrc <<'===='
# configuration file generated by Bochs
plugin_ctrl: unmapped=true, biosdev=true, speaker=true, extfpuirq=true, parallel=true, serial=true, gameport=true, iodebug=true
config_interface: textconfig
display_library: x
memory: host=64, guest=64
romimage: file="@---BIOS---@", address=0xffff0000, options=none
vgaromimage: file="@---VGABIOS---@"
boot: disk
floppy_bootsig_check: disabled=0
# no floppya
# no floppyb
ata0: enabled=true, ioaddr1=0x1f0, ioaddr2=0x3f0, irq=14
ata0-master: type=disk, path="@---HD---@", mode=flat, cylinders=0, heads=16, spt=32, sect_size=512, model="Generic 1234", biosdetect=auto, translation=auto
ata0-slave: type=none
ata1: enabled=true, ioaddr1=0x170, ioaddr2=0x370, irq=15
ata1-master: type=none
ata1-slave: type=none
ata2: enabled=false
ata3: enabled=false
optromimage1: file=none
optromimage2: file=none
optromimage3: file=none
optromimage4: file=none
optramimage1: file=none
optramimage2: file=none
optramimage3: file=none
optramimage4: file=none
pci: enabled=1, chipset=i440fx
vga: extension=vbe, update_freq=5, realtime=1
cpu: count=1:1:1, ips=4000000, quantum=16, model=pentium, reset_on_triple_fault=1, cpuid_limit_winnt=0, ignore_bad_msrs=1, mwait_is_nop=0
print_timestamps: enabled=0
debugger_log: -
magic_break: enabled=0
port_e9_hack: enabled=0
private_colormap: enabled=0
clock: sync=realtime, time0=local, rtc_sync=0
# no cmosimage
log: -
logprefix: %t%e%d
debug: action=ignore
info: action=report
error: action=report
panic: action=ask
keyboard: type=mf, serial_delay=250, paste_delay=100000, user_shortcut=none
mouse: type=ps2, enabled=false, toggle=ctrl+mbutton
sound: waveoutdrv=dummy, waveout=none, waveindrv=dummy, wavein=none, midioutdrv=dummy, midiout=none
speaker: enabled=true, mode=sound
parport1: enabled=true, file=none
parport2: enabled=false
com1: enabled=true, mode=null
com2: enabled=false
com3: enabled=false
com4: enabled=false
ne2k: ioaddr=0x280, irq=3, mac=b0:c4:20:00:00:00, type=isa, ethmod=slirp, script="bochs.slirp.conf"
====
# NOTE depending on its build bochs can be expected to need
# user terminal interaction to handle the network card
# (it detects an error condition, which is apparently harmless)
#
# we try to arrange that bochs dialogue does not end up in the log
exec bochs -f bochsrc -rc bochsstartrc >/dev/tty 2>&1
exit
____
chmod +x f_runbochs.sh

hw="$B"'/f_runbochs.sh /usr/share/bochs/BIOS-bochs-legacy /usr/share/bochs/VGABIOS-lgpl-latest'

( ( set -e
  set -x
  sh "$S"/z_tools.sh
# ----------------------- build a crosscompiler and other cross-utils
  sh "$S"/z_xack.pcc.sh
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
