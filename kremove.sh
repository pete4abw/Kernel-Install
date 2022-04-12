#!/bin/sh
# program to remove a kernel
# Peter Hyman, pete@peterhyman.com
# No warranties, and free to use and copy

# Prefixes

BOOT="/boot"
LIB="/lib/modules"
USDIR="/usr/src"
CKV=`uname -r`
ISREMOVED=0

# root test
if [ $UID -ne "0" ] ; then
	echo "Only root can do...Exit"
	exit 1
fi

# usage test
if [ $# -ne "1" ] ; then
	echo "Usage: \"$0 kernel_version\"...Exit"
	exit 1
fi

# current kernel test
if [ "$CKV" ==  "$1" ] ; then
	echo "Cannot remove current kernel...Exit"
	exit 1
fi 

# modules test
if [ ! -e "$LIB/$1" ] ; then
	echo "Cannot find module directory. Is kernel $1 installed? Exiting..."
	exit 1
fi

# individual file tests
echo "Removing kernel $1 boot directory files..."
if [ ! -e "$BOOT/initrd-$1.gz" ] ; then
	echo "Can't find kernel initrd-$1.gz to remove...Continuing"
else
	rm -v $BOOT/initrd-$1.gz
	ISREMOVED=1
fi

if [ ! -e "$BOOT/vmlinuz-$1" ] ; then
	echo "Can't find kernel vmlinuz-$1 to remove...Continuing"
else
	rm -v $BOOT/vmlinuz-$1
	[ $ISREMOVED -eq 0 ] && ISREMOVED=1
fi

if [ ! -e "$BOOT/System.map-$1" ] ; then
	echo "Can't find kernel System.map-$1 to remove...Continuing"
else
	rm -v $BOOT/System.map-$1
	[ $ISREMOVED -eq 0 ] && ISREMOVED=1
fi

if [ ! -e "$BOOT/config-$1" ] ; then
	echo "Can't find kernel config-$1 to remove...Continuing"
else
	rm -v $BOOT/config-$1
	[ $ISREMOVED -eq 0 ] && ISREMOVED=1
fi

[ $ISREMOVED -eq 0 ] &&	echo "Odd that no files removed from $BOOT directory"

# Already tested for existence of lib directory
echo "Removing module directory $LIB/$1"
rm -fr $LIB/$1

# Remove kernel source directory if present
if [ ! -e "$USDIR/linux-$1" ] ; then
	echo "Can't find $USDIR/linux-$1 source directory...Continuing"
else
	echo "Removing kernel $1 source directory or link..."
	rm -fr $USDIR/linux-$1
fi

echo "Kernel $1 removed. EFI directories, if any, not touched."

