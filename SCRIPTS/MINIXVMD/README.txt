2023-03-05

[abc...]_*.sh - scripts usable as-is _for_us_
                with the corresponding build platform
                (named after compiler, target_hw_implementation
                and their milestones, kind of - a funny fact,
                Tendra C compiler and Tiny C Compiler both
                name their main binary "tcc")
                a_*.sh - build:
                         provides a generic Minix-vmd installation
                         as
                       * a reproducible target OS file hierarchy
                       * a reproducible bootable disk image
                       * a pre-run directly usable bootable half-disk image
                d_qemu_gmake.sh - a proof of concept, building GNU make

[klm...]_.sh  - scripts aiming at "aggregated", larger milestones
                l_*.sh - skip the intermediate steps / disk images
                         which reduces the needed storage capacity

[...xyz]_*.sh        - scripts doing the hard work

NOTE: The host compiler is not being used past z_xack.*.sh scripts.
To test a different compiler it is sufficient to create a new a_...sh
file and compare its results with the results of the other a_*.sh files

NOTE: "grep %%%" shows the relevant sha256sum results in the corresponding
logs, for easy comparison.

A REMINDER: Do *NOT* trust the scripts, you *MUST* examine and understand
them for the verification to be meaningful.

-----------------------------------------------------------
On systems lacking /dev/zero, a sufficiently large file filled with zeros
will do as well. Otherwise a small program, even without changes in the
scripts, if combined with a named pipe in /dev.
-----------------------------------------------------------
To start Minix on real hardware you may have to switch
to the bios disk driver (hd=bios) in the monitor.
The hardware must support the traditional (aka "legacy")
bios boot, to be able to boot Minix.
-----------------------------------------------------------
To start Minix on real hardware you may have to adjust
the memory end address down in the Minix boot monitor
(with the emssize=....   command)
otherwise it can be too much for Minix to recognize.
You will probably need at least 64MB (emssize=65536)
for the step where Tiny C Compiler is built with TeNDRA.
-----------------------------------------------------------
To be able to log in to Minix over telnet
(e.g. for troubleshooting) :

NOTE Debian qemu seems to be built without isa-ne2k support,
we resorted to bochs (the config files arranged in scripts ?_*.bochs*
and activate the network card emulation and telnet redirection, as a
reference, even though network in Minix is _not_ being activated/used
for builds)

NOTE when the network device is being used, bochs can issue diagnostics
about the card being reset, and ask what it shall do,
choose "always continue".

The Minix "boot environment" shall be modified by adding via edparams
DPETH0=280:3

A file must be created in Minix:
---------------
/etc/inet.conf
---------------
eth0 DP8390 0 { default; };
---------------

One more file is needed (/etc/inetd.conf with the necessary contents
and /etc/services are also needed, but they shall be already present)
---------------
/usr/etc/rc
---------------
#!sh

set -x

PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH

inet
ifconfig -h 10.0.2.15 -n 255.255.255.0
add_route -g 10.0.2.2
echo "nameserver 10.0.2.3" > /etc/resolv.conf

inetd &

exit
---------------

Also useful to add in /etc/profile :
---------------
stty intr ^C

export PATH=/bin:/sbin:/usr/bin:/usr/sbin
---------------

After login on the console as root, do

 passwd root     (important, set some password,
                  otherwise login over telnet will be refused)

Then it should be possible to log in, for example
from the host computer running an emulator
which forwards port 2223 to 23, by

 telnet 127.0.0.1 2223

NOTE (at least om Minix-2) passwd only works when /dev/tty is available,
which happens after login, not if you get an sh session via /etc/rc,
in the latter case passwd will loop and the only way to stop it is a
reset of the computer
-----------------------------------------------------------
