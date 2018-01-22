#!/bin/sh
# (c) Michael R. Tirado GPL Version 3 or any later version.
#-----------------------------------------------------------------------------
RELEASE_PATH="$HOME/.git_release/"
set -e
print_usage()
{
	echo "usage: git_release.sh <tarfile>"
	echo ""
	echo "creates release files at $RELEASE_PATH"
	echo ""
	exit 1
}

if [ "$1" == "" ]; then
	print_usage
fi

TARFILE="$1"
TARPATH="$RELEASE_PATH/$TARFILE"
TOPDIR="$PWD"
SAVEDIR=""

if [ -e "$TARPATH" ]; then
	echo "file $TARPATH already exists"
	echo "press f to force removal"
	read -n 1 -s ACK
	if [ $ACK != 'f' ]; then
		exit 2
	fi
	rm -r "$TARPATH"
	rm -r "$TARPATH.tar.xz"
fi

copy_git_dir()
{

	IFS=; (git ls-files -z) | while read -r -d $'\0' FILE; do
		if [ -d "$FILE" ]; then
			echo "DIR [$FILE]"
			if [ -f "$FILE/.git" ]; then
				SAVEDIR="$PWD"
				mkdir -pv "$TARPATH/$FILE"
				cd "$FILE"
				copy_git_dir "$FILE"
				cd "$SAVEDIR"
			fi
		else
			if [ ! -e $(dirname "$TARPATH/$1/$FILE") ]; then
				mkdir -p "$TARPATH/$1/$FILE"
				rmdir "$TARPATH/$1/$FILE"
			fi
			cp -va "$FILE" "$TARPATH/$1/$FILE"
		fi
	done
}

mkdir -pv "$TARPATH"
copy_git_dir
cd "$RELEASE_PATH"
tar -cJf "$TARPATH.tar.xz" "$TARFILE"

