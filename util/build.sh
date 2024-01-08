#!/bin/sh
# Build T2FMDML utilities.

iscc()
{
	# In config.sh, set ISPATH to the complete path of the installed Inno Setup
	# Compiler (ISCC.exe).
	# Also, set WINE to 'wine' or the location of your Wine binary if you need
	# to use it.
	ARGS=$1
	$WINE "$ISPATH" $ARGS
}

cd $(dirname $0)

. ../common.sh

if test -f ../config.sh; then
	. ../config.sh
fi

_7Z_VER="2301"

rm -f "T2FMDML_${T2FMDML_VER}.zip"

echo "Checking for prerequisites..."
check_command 7z
check_command curl
test -n "$ISPATH" && echo "ISCC path defined." || abort "ISCC path (ISPATH) not defined!"

if test ! -f ./7za.exe; then
	cd ..
	echo "Retrieving 7-Zip binary..."
	mkdir -p cache
	curl_fetch "7z${_7Z_VER}-extra.7z" "https://7-zip.org/a/7z${_7Z_VER}-extra.7z" db3a1cbe57a26fac81b65c6a2d23feaecdeede3e4c1fe8fb93a7b91d72d1094c
	extract "7z${_7Z_VER}-extra.7z" util/updater 7za.exe
	cd util
	echo "Retrieved 7-Zip binary."
fi

echo "Building T2FMDML Updater..."
cd updater
iscc "-Qp updater.iss" && echo "T2FMDML Updater built successfully." || abort "T2FMDML Updater failed to build!"

echo

