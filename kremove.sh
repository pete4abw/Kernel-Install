#!/bin/sh
# program to remove a kernel
# Peter Hyman, pete@peterhyman.com
# No warranties, and free to use and copy

# Prefixes

BOOT="/boot"
LIB="/lib/modules"
USDIR="/usr/src"
CKV=`uname -r`

#root test
if [ $UID -ne "0" ] ; then
	echo "Only root can do...Exit"
	exit
fi

if [ $# -ne "1" ] ; then
	echo "Usage: \"$0 kernel_version\"...Exit"
	exit
fi

if [ "$CKV" ==  "$1" ] ; then
	echo "Cannot remove current kernel...Exit"
	exit
fi 

if [ ! -e "/boot/vmlinuz-$1" ] ; then
	echo "Can't find kernel vmlinuz-$1...Exit"
	exit
fi

CWD="$PWD"

cd $BOOT
echo $PWD
rm config-$1 System.map-$1 initrd-$1.gz vmlinuz-$1

cd $LIB
echo $PWD
rm -fr $1

cd $USDIR
echo $PWD
rm -fr linux-$1

cd "$CWD"

exit

