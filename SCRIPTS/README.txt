verifiable from-scratch source-only bootstrap
by an 2022, 2023
put in public domain,
if/where public domain is not recognized, then 0BSD

last change: 2023-03-06

The expected usage is:

1. prepare an empty writable build directory with several hundred MiB
   available space

2. set up the references to the relevant paths,
   in bourne shell notation ("/XXXX" denotes the absolute path to
   the build template main directory, "/YYYY" the absolute path to
   your writable build directory) :
    A=/XXXX ; B=/YYYY ; export A B

3. examine and possibly adjust "$A"/SCRIPTS/MINIXxxx/?_*.sh
   or create new ones using the present ones as templates

4. run
    sh your_choice_of_?_...sh
   check the resulting checksums by 'grep %%% "$B"/*Log*'
   and verify against the expected values (in ../README.txt
   and ../VERIFY_SHA256, then also against ../VERIFY_SHA512)

# end of README
