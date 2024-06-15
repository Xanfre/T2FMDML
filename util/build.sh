#!/bin/sh
# Build T1GFMDML and T2FMDML utilities.

iscc()
{
	# In config.sh, set ISPATH to the complete path of the installed Inno Setup
	# Compiler (ISCC.exe).
	# Also, set WINE to 'wine' or the location of your Wine binary if you need
	# to use it.
	ARGS=$1
	$WINE "$ISPATH" $ARGS
}

nmake()
{
	# In config.sh, set VSPATH and SDKPATH to the locations of your base Visual
	# Studio 2008 or Visual C++ 9 installation and your Windows SDK installation,
	# respectively.
	# Also, set WINE to 'wine' or the location of your Wine binary if you need
	# to use it.
	ARGS=$1
	if test -z "$WINE"; then
		# This path will only persist for the runtime of this function.
		# Do not try to use this path in the global environment.
		export PATH="${VSPATH}\\Common7\\IDE:${VSPATH}\\VC\\bin:${SDKPATH}\\bin"
	else
		export WINEPATH="${VSPATH}\\Common7\\IDE;${VSPATH}\\VC\\bin;${SDKPATH}\\bin"
	fi
	export INCLUDE="${VSPATH}\\VC\\include;${SDKPATH}\\include;${FLTKINC}"
	export LIB="${VSPATH}\\VC\\lib;${SDKPATH}\\lib;${FLTKLIB}"
	export LIBPATH="${VSPATH}\\VC\\lib"
	if test -z "$WINE"; then
		nmake.exe $ARGS
	else
		$WINE cmd /c nmake.exe $ARGS
	fi
}

cd $(dirname $0)

. ../common.sh

if test -f ../config.sh; then
	. ../config.sh
fi

_7Z_VER="2301"

rm -rf updater/Output

echo "Checking for prerequisites..."
check_command 7z
check_command curl
test -n "$ISPATH" && echo "ISCC path defined." || abort "ISCC path (ISPATH) not defined!"
test -n "$VSPATH" && echo "Visual Studio path defined." || abort "Visual Studio path (VSPATH) not defined!"
test -n "$SDKPATH" && echo "Windows SDK path defined." || abort "Windows SDK path (SDKPATH) not defined!"
test -n "$FLTKINC" && echo "FLTK include path defined." || abort "FLTK include path (FLTKINC) not defined!"
test -n "$FLTKLIB" && echo "FLTK library path defined." || abort "FLTK library path (FLTKLIB) not defined!"

if test ! -f ./7za.exe; then
	cd ..
	echo "Retrieving 7-Zip binary..."
	mkdir -p cache
	curl_fetch "7z${_7Z_VER}-extra.7z" "https://7-zip.org/a/7z${_7Z_VER}-extra.7z" db3a1cbe57a26fac81b65c6a2d23feaecdeede3e4c1fe8fb93a7b91d72d1094c
	extract "7z${_7Z_VER}-extra.7z" util/updater 7za.exe
	cd util
	echo "Retrieved 7-Zip binary."
fi

echo "Building Updater..."
cd updater
mkdir -p Output/T1GFMDML Output/T2FMDML
iscc "-Qp -DModName=T1GFMDML updater.iss" && echo "T1GFMDML Updater built successfully." || abort "T1GFMDML Updater failed to build!"
cp updater.sh Output/T1GFMDML/
sed -i 's|T2FMDML updates|T1GFMDML updates|; s|MOD_NAME="T2FMDML"|MOD_NAME="T1GFMDML"|' Output/T1GFMDML/updater.sh
iscc "-Qp -dModName=T2FMDML updater.iss" && echo "T2FMDML Updater built successfully." || abort "T2FMDML Updater failed to build!"
cp updater.sh Output/T2FMDML/
cd ..

echo "Building fmdmlcfg..."
cd fmdmlcfg
if test -f ./fmdmlcfg.exe; then
	nmake "-f Makefile-vc.mak clean" || abort "Failed to clean before building miss16shim!"
fi
nmake "-f Makefile-vc.mak" && echo "fmdmlcfg built successfully." || abort "fmdmlcfg failed to build!"

echo

