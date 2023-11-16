2023-03-05

[abc...]_*.sh - scripts usable as-is _for_us_
                with the corresponding build platform
                (named after compiler, target_hw_implementation
                and their milestones, kind of - a funny fact,
                Tendra C compiler and Tiny C Compiler both
                name their main binary "tcc")
                a_*.sh - build:
                         provide a generic Minix-2 installation
                         as
                       * a reproducible target OS file hierarchy
                       * a reproducible bootable disk image
                       * a pre-run directly usable bootable half-disk image
                b_*.sh - further build, after succesful a_*:
                         provide TenDRA C/C++ compiler (ANSI C)
                         and Tiny C Compiler (C99)
                         as
                       * a reproducible target OS file hierarchy
                       * a reproducible bootable disk image
                       * a pre-run directly usable bootable half-disk image
                c_*.sh - further build, after succesful b_*:
                         provide TenDRA C/C++ compiler (ANSI C)
                         and _stable-self-rebuilt_ Tiny C Compiler (C99)
                         as
                       * a reproducible target OS file hierarchy
                       * a reproducible bootable disk image
                       * a pre-run directly usable bootable half-disk image
                d_qemu_gmake.sh - if desired, can be used to build gmake,
                         either with ACK or with Tiny C Compiler,
                         either creating a file tree with all the files or
                         just providing the result in the hd0 disk image file
                         (choices are made by commenting/uncommenting
                         the commands in this script)

[klm...]_.sh  - scripts aiming at "aggregated", larger milestones

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
to the bios disk driver (c0=bios) in the monitor.
The hardware must support the traditional (aka "legacy")
bios boot, to be able to boot Minix.
-----------------------------------------------------------
To start Minix on real hardware you may have to adjust
the memory end address down in the Minix boot monitor
(with the memory=....   command)
otherwise it can be too much for Minix to recognize.
You will probably need at least 64MB (memory=...:4000000)
for the step where Tiny C Compiler is built with TeNDRA.
-----------------------------------------------------------
2022-09-04 an

We build the kernel with support for NE2000 card and PTYs
(also RTL8139 / PCI but this did not look usable in the end).

qemu can possibly support the ne2k_isa card, but this is not enabled in
Debian build of qemu, only ne2k_pci.

qemu supports rtl8139 also supported by Minix but activating pci and
rtl8139 in Minix and choosing rtl8139 in qemu did not unfortunately
produce a working network, even though the card was recognized by Minix.

We went with bochs and NE2000.

bochs works and is useful as an extra hardware platform to test
the build on, that's why it is worth the trouble to configure it.
-----------------------------------------------------------
To be able to log in to Minix over telnet
(e.g. for troubleshooting) :

The Minix "boot environment" shall be modified by adding
DPETH0=280:3

A file must be created in Minix: /etc/inet.conf :
eth0 DP8390 0 { default; };

After inloggning on the console as root, do

 export PATH
 inet            (diagnostics, possibly about adjustments in /dev
                  and about the found card)
 dhcpd &         (bochs can issue diagnostics about the card being reset,
                  choose "always continue")
 tcpd telnet in.telnetd &

 passwd root     (important, set some password)

Then it should be possible to log in, for example
from the host computer running an emulator
which forwards port 2223 to 23, by

 telnet 127.0.0.1 2223

An alternative, manual network setup can otherwise look as follows:

 ifconfig -h 10.0.2.15 -n 255.255.255.0
 add_route -g 10.0.2.2
 cat >/etc/resolv.conf <<'____'
nameserver 10.0.2.3
____

NOTE passwd only works when /dev/tty is available,
which happens after login, not if you get an sh session
via /etc/rc, in the latter case passwd will loop and the
only way to stop it is a reset of the computer
-----------------------------------------------------------
