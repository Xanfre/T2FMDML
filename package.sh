#!/bin/sh
# Package T1GFMDML and T2FMDML for release.

cd $(dirname $0)

. ./common.sh

if test -f ./config.sh; then
	. ./config.sh
fi

T2FMDML_VER="R4"

rm -f "T1GFMDML_${T2FMDML_VER}.zip" "T2FMDML_${T2FMDML_VER}.zip"

echo "Checking for prerequisites..."
check_command 7z

if ! test -f ./util/updater/Output/T1GFMDML/updater.exe \
	|| ! test -f ./util/updater/Output/T2FMDML/updater.exe; then
	abort "The updater could not be located. Please build it first."
fi

echo "Packaging T1GFMDML..."
archive "T1GFMDML_${T2FMDML_VER}.zip" ./T1GFMDML/*\ ./util/updater/Output/T1GFMDML/updater.exe\ ./util/updater/Output/T1GFMDML/updater.sh\ ./LICENSE
echo "Packaging T2FMDML..."
archive "T2FMDML_${T2FMDML_VER}.zip" ./T2FMDML/*\ ./util/updater/Output/T2FMDML/updater.exe\ ./util/updater/Output/T2FMDML/updater.sh\ ./LICENSE

echo

