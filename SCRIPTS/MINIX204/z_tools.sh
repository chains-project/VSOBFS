#!bourne sh
#
# you may need to edit this script (you have been warned)
# v.0.5 2023-02-05
# v.0.4 2022-09-24
# v.0.3 2022-08-12
# v.0.2 2022-08-08
# v.0.1 2022-08-05

# this script must be run before other z_*.sh scripts,
# it expects a list over tool references in $tools
# (via environment)

# tools used: (hostcc is the primary candidate to be adjusted)
# absolute path in the second column is OK, otherwise it
# is at the script start imported from your current $PATH
#
# used_as    named_in_the_host_system
#tools="
#[            [
#ar           ar
#bzip2        bzip2
#cat          cat
#chmod        chmod
#cp           cp
#dd           dd
#diff         diff
#expr         expr
#find         find
#gzip         gzip
#hostcc       cc
#install      install
#ln           ln
#ls           ls
#mkdir        mkdir
#printf       printf
#rm           rm
#sh           sh
#sha256sum    sha256sum
#sort         sort
#tar          tar
#xargs        xargs
#"

set -e

. "$S"/z_.sh

case "$tools" in
('') die "PROBLEM: \$tools does not look set up" ;;
esac

set -- $tools
while [ "$#" -gt 1 ]; do
  tool="$1"; shift
  localtool="$1"; shift
  l="$localtool"
  [ -x top/bin/"$tool" ] && continue
  case "$localtool" in
  (/*) ;;
  (*)
    localtool="$(which "$localtool")"
    case "$localtool" in
    (/*) ;;
    (*) die "PROBLEM: '$tool' is not available (hinted as '$l')" ;;
    esac
    ;;
  esac
  [ -x "$localtool" ] || die "PROBLEM: '$localtool' can not be executed"
  ln -s "$localtool" top/bin/"$tool"
done

exit
