#!/bin/sh
# Package T2FMDML for release.

cd $(dirname $0)

. ./common.sh

if test -f ./config.sh; then
	. ./config.sh
fi

T2FMDML_VER="R4"

rm -f "T2FMDML_${T2FMDML_VER}.zip"

echo "Checking for prerequisites..."
check_command 7z

if ! test -f ./util/updater/Output/updater.exe; then
	abort "The updater could not be located. Please build it first."
fi

echo "Packaging T2FMDML..."
archive "T2FMDML_${T2FMDML_VER}.zip" ./T2FMDML/*\ ./util/updater/Output/updater.exe\ ./util/updater/updater.sh\ ./LICENSE

echo

