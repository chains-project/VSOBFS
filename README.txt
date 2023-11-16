verifiable source-only bootstrap from scratch
to a Posix-like OS and a C99 compiler
---------------------------------------------
by an 2022-2023

All parts of the project not covered by someone else's copyright
are put in public domain. For jurisdictions which do not recognize
public domain the project is under Zero Clause BSD license (SPDX: 0BSD)

Copyright 2022-2023 an

Permission to use, copy, modify, and/or distribute this software for
any purpose with or without fee is hereby granted.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

v.1.0 2023-03-06
v.0.10 2023-03-05
v.0.9 2023-03-03
v.0.8 2023-02-26
v.0.7 2023-02-07
v.0.6 2023-02-02
v.0.5 2023-01-25
v.0.4 2022-09-24
v.0.3 2022-09-04
v.0.2 2022-08-08
v.0.1 2022-08-05

a template which can be used to reproducibly cross-compile
Minix-vmd kernel and userspace, on an arbitrary Posix-like system
and then use it as a starting point for reproducible
software builds for many/any other platforms

also avalable in a Minix-2 variation, but Minix-vmd has a more convenient
file system (with symlinks and longer file names), virtual memory and
a richer API which makes it more comfortable for further development

no pre-existing binary blobs are being used in the build process,
the binaries (kernels and toolchains) involved in the bootstrapping shall
come from as wide as possible variety of build platforms, origins and
architectures, yielding always the same result, bit-for-bit

requirements:
-------------
- a POSIX-like OS on a 32+ bit CPU as a host for the building procedure
- an ANSI (C89) C compiler for the host OS
- either an i486+ legacy-bios-compatible system emulator on the host system
  or a corresponding physical hardware along with a means to write
  and read its hard disk (128MiB is enough)

the host hardware and software does not have to be open-source,
nor needs to be trusted

the outcome:
------------
A *reproducible* raw disk image with an mbr partition table and a
Minix-vmd installation (omitting GNU and X11) in the first partition,
usable on hardware or emulators. When booted, it unpacks the OS data
from its second partition (the disk's second half) which then can be
used at will.

Then the installation can be easily used and modified via scripting, 
if you supply an rc script as a compressed (by the "compress" utility)
tar file on the disk second half. For examples see the z_* build
scripts. Host-native "compress" is prepared as a part of the build,
if not otherwise.

the data:
---------
NOTE! the data consists of three parts,
all of them subject to your review, in differing ways:

SOURCES/
  mostly the historical data, present in multiple copies across
  independent sites, verifiable via checksums

  sources are given and CAN *NOT* BE CHANGED
  but they shall be verified for authenticity
  and/or audited for bugs and backdoors

PATCHES/
  the patches (to the sources), developed by us,
  they DO need your review and understanding, because
  potentially we could implant harmful code there

  patches SHALL *NOT* BE CHANGED because this would make the result
  incompatible with reviews made by any parties without/before
  the corresponding change

SCRIPTS/
  the scripts which describe the verifiable bootstrapping
  sequence, they are
  *NOT* necessarily directly usable on each given host platform,
  moreover it is the intention that they
  *ARE* to be modified, to be used on a variety of even yet unknown
  platforms, to confirm and ensure the independence of the results
  from the building platform; these scripts
  SHALL NOT be seen as trustable and DO need your review before usage

  scripts ARE SUBJECT TO CHANGES by you, there can be also
  multiple useful versions of them, not included in this original
  package, each of them MUST be analyzed before usage,
  the responsibility is yours!

  MINIX204/ (NOTE: the recommended choice is Minix-vmd, below)
            to build Minix binary data and reproducible disk images
            providing usable Minix-2.0.4 instances,
            vanilla and also one with TenDRA and Tiny CC compilers
            (in /opt + /usr/local/bin)

            the root user can log in there with an empty password

            the disk images have the size of 100MB

            their sha256sums calculated as in the scripts
            shall strictly correspond to the following:

86ec6e6706de3ce27635b4cdfa5f1450c7ebc6aaeded8d8b9eb06e7e11f7f277 minix2_ref_0
cc92289500480944f79a79018f1b4b3671bc8541f93e79872e87db35bcf1ffcd min2tin_ref_0
23c31f500865e89a6526cb78dd8bd50cf8f5b5a972c3ecf79069f1e7a887344c MINIX2
532af959700e02eb0160d18ea82e1a47cbd66b2812dcf5e09cef917309478cf0 TINYCC

            their sha512sums calculated in a corresponding way
            i.e. for disk images: sha512sum, for file trees:
             find . -type f | LANG=C sort | xargs sha512sum | sha512sum
            shall strictly correspond to the following:

32c3a6515cb2cfedd5c281fc498de63fd8ce49d8f0c4eb634f31f35e58d2b77303db6f527c760afc4d62a6cc480b1fe16f468967aeb5f822addb6128a383d8ed minix2_ref_0
5c7ef077e799687246d575ca4935b1703fbb36678874cd618eaf1f6d7548cb2356abdbe34977d3914a6a0274c82e291130da576dcca4a17e1bf5174b16f31fee min2tin_ref_0
7837a857eee555b2d476bc207f41f894d8bd7548422ba7a16d6c785b7f2fc8e5c151ea9614b4a3dfd1f380bdc14364944e20d4160a180976be96b78efda4ce30 MINIX2
02eb8f17b4620679609719b664de0f8792a0826c7e725e6e6ef208514ae56890eddcb098ccad61ca3fab6e50a42344cb20fac87b4115df086e5f91b354e35873 TINYCC

  MINIXVMD/ as for MINIX204 above
            but the disk images have the size of 128MB
            TenDRA C Compiler providing Minix-2 API is in /opt/tendra/bin
            Tiny C Compiler   providing Minix-2 API is in /opt/tinycc/bin
            Tiny C Compiler   providing Minix-vmd APIs (Minix/BSD)
                              is in /usr/bin

            their sha256sums calculated as in the scripts
            shall strictly correspond to the following:

05c85fd961a4ee501c72fb426e788d6b15b52974ca2452f612f0aa4a3e23d8fb minixvmd_ref_0
59db99726254488a61b554fa458e439de7d41da887673e66557bed28990da0c2 minvtin_ref_0
77c0e627a352a64a6b5c2485d9cc8591615436eea70d80f3649dca6688a62e50 MINIXVMD
ef56b41cda3ca083889c990a6188c35274c3ea83885bcf5e1edccbeb6a21869f TINYCC

            their sha512sums calculated in a corresponding way
            i.e. for disk images: sha512sum, for file trees:
             ( find . -type f | LANG=C sort | xargs sha512sum
               find . -type l | LANG=C sort |
                ( while read a; do printf '%s\n' "$a"; readlink "$a"; done ) ) | sha512sum
            shall strictly correspond to the following:

94721abbb5e76284e0edb309134230e2b5f97bad84f86205d50426a7562df47d5704fc6ab525c7233b09df4c0b28851d9d96e7f4302cafbd73e1ada59144e317 minixvmd_ref_0
d0e01e3583aba0d970f52be64acfc7ff47ba6dc87e21e4258b19163125c3800c0ebe1ea42ed7fcec09373682fae95a38eaf0af44d526c9c46f4ed00d5c14af73 minvtin_ref_0
26ebb0cfaef9e8acbd3447f49d6fd507c34171daf0408a153d3e82afb1708e6a0d6daca4d7b068331f5aea26170311e7b45418bdf5b4760f4245605b0dd26fc4 MINIXVMD
4fccfafe20d8a0aab8ac5c1c6e2825a90c314f23fbae0132c5623c4b70e219054ad8f249138ea34564b7d4a5a1fff36d21df76803acc76ffd2870b346aa59fb7 TINYCC

copies of checksums of the disk images (omitting those of the file trees)
are also present in the files VERIFY_SHA256 and  VERIFY_SHA512

end of README
