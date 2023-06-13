#!/bin/sh
# Package T2FMDML for release.

abort()
{
	echo "$1"
	echo "Aborting!\n"
	exit 1
}

check_command()
{
	CMD=$1
	command -v "$CMD" > /dev/null 2>&1 && echo "Found ${CMD} executable." || abort "Could not find ${CMD}!"
}

check_function()
{
	FUNC=$1
	type "$FUNC" | sed "s/${FUNC}//" | grep -qwi function > /dev/null 2>&1 && echo "Function '${FUNC}' exists." || abort "Function '${FUNC}' not defined!"
}

curl_fetch()
{
	FILE=$1
	SHA256=$3
	if [ ! -f "cache/${FILE}" ]; then
		echo "Trying to download ${FILE}...\n"
		curl -LR -o "cache/${FILE}" "$2" && echo "\nDownloaded ${FILE}." || abort "\n${FILE} could not be fetched!"
	fi
	echo "${SHA256}" "cache/${FILE}" | sha256sum --check --status  && echo "${FILE} SHA256 matches ${SHA256}" || abort "${FILE} SHA256 does not match ${SHA256}!"
}

extract()
{
	FILE=$1
	7z x -aoa -y -o"$2" "cache/${FILE}" $3 > /dev/null 2>&1 && echo "Successfully extracted ${FILE}." || abort "Could not extract ${FILE}!"
}

archive()
{
	FILE=$1
	7z a -y "$FILE" $2 > /dev/null 2>&1 && echo "Successfully created ${FILE}." || abort "Could not make ${FILE}!"
}

# Example 'iscc' function to be placed in 'iscc.sh':
#
# iscc()
# {
# 	FILE=$1
# 	wine C:\\Program\ Files\\Inno\ Setup\ 6\\ISCC.exe $FILE
# }

T2FMDML_VER="R4"
_7Z_VER="2201"
_7Z_SHA256="fb776489799cd5ca0e151830cf2e6a9819c5c16c8e7571ff706aeeee07da2883"

cd $(dirname $0)

rm -f "T2FMDML_${T2FMDML_VER}.zip"

echo "Checking for prerequisites..."
check_command 7z
check_command curl
test -f	iscc.sh && echo "Found 'iscc.sh'." || abort "Cannot source 'iscc.sh' for retrieving updater build configuration."
. ./iscc.sh
check_function iscc

echo "Building T2FMDML Updater..."
mkdir -p cache
curl_fetch "7z${_7Z_VER}-extra.7z" "https://7-zip.org/a/7z${_7Z_VER}-extra.7z" "$_7Z_SHA256"
extract "7z${_7Z_VER}-extra.7z" . 7za.exe
iscc "/Qp updater.iss"
if [ $? -ne 0 ]; then
	abort "Updater failed to build!"
fi

echo "Packaging T2FMDML..."
archive "T2FMDML_${T2FMDML_VER}.zip" "./T2FMDML/* ./Output/updater.exe ./LICENSE"

echo ""

