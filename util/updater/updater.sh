#!/bin/sh
# Check for T2FMDML updates.

abort()
{
	echo "$1"
	echo "Aborting!"
	echo
	exit 1
}

cd $(dirname $0)

PUBLISHER="Xanfre"
MOD_NAME="T2FMDML"
CHECK_URL="https://api.github.com/repos/${PUBLISHER}/${MOD_NAME}/releases/latest"
CURRENT_VER=""

echo "Checking for prerequisites..."
for CMD in curl 7z; do
	command -v "$CMD" > /dev/null 2>&1 && echo "Found ${CMD} executable." \
		|| abort "Failed to find ${CMD}. Please ensure it is installed.";
done

test -f ./version && CURRENT_VER=$(cat version)

echo "Checking for latest version..."
curl -L -o .latest "$CHECK_URL" > /dev/null 2>&1 \
	|| abort "The update check failed. Please check your network connectivity and try again."
NEW_VER=$(grep -o \"tag_name\":\ \".*\" .latest | cut -d\" -f4)
rm -f .latest
test -z "$NEW_VER" \
	&& abort "Could not get valid version information. Assuming that the latest version is already installed."

UPDATE_URL="https://github.com/${PUBLISHER}/${MOD_NAME}/releases/download/${NEW_VER}/${MOD_NAME}_${NEW_VER}.zip"

if test -z "$CURRENT_VER" || ! test "$CURRENT_VER" = "$NEW_VER"; then
	read -p "A ${MOD_NAME} update was found. Download and install it? [y/N] " CHOICE
	case $CHOICE in
		[yY])
			echo "Downloading the latest version of ${MOD_NAME}..."
			curl -L -o ".${MOD_NAME}.zip" "$UPDATE_URL" > /dev/null 2>&1 \
				|| abort "The latest version of ${MOD_NAME} could not be downloaded. Please check your network connectivity and try again."
			echo "Downloaded the latest version of ${MOD_NAME}."
			echo "Extracting the downloaded archive..."
			rm -rf *.dml dbmods sq_scripts
			7z x -aoa -y ".${MOD_NAME}.zip" > /dev/null 2>&1
			SUCCESS=$?
			rm -f ".${MOD_NAME}.zip"
			test $SUCCESS -eq 0 && echo "Extracted the downloaded archive." \
				|| abort "Failed to extract the downloaded archive. Please ensure you have appropriate write access."
			echo "The latest version of ${MOD_NAME} was successfully downloaded and installed. All files in the installation directory should now be up-to-date."
			;;
		*)
			echo "Keeping current version."
			;;
	esac
else
	echo "Your installation of ${MOD_NAME} is up-to-date. No further updates were found."
fi

echo

