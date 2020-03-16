#!/bin/sh
# program to install a kernel
# Peter Hyman, pete@peterhyman.com
# No warranties, and free to use and copy

# do some checks
if [ $UID -ne 0 ]; then
	echo "must run as root to install a kernel"
	exit
fi

if [ ! -f .config ] ; then
	echo "no .config file found"
	exit
fi

if [ ! -f Makefile ] ; then
	echo "no Makefile file found"
	exit
fi

# Set some directories and detect any links
USDIR="/usr/src"
PWDIR=$PWD
REALPWDIR=`realpath .`

# unusual but possible. If we start in /usr/src/linux, we
# need to change to the real directory so we can set links
# later
[ "$PWDIR" != "$REALPWDIR" ] && cd "$REALPWDIR"

# Kernel, Patch, Sublevel, and full kernel version
# set from Makefile

KV=`grep -m 1 "VERSION"		Makefile | cut -d ' ' -f 3`
PL=`grep -m 1 "PATCHLEVEL"	Makefile | cut -d ' ' -f 3`
SL=`grep -m 1 "SUBLEVEL"	Makefile | cut -d ' ' -f 3`
FV=$KV.$PL.$SL

FVDIR="$USDIR/linux-$FV"

cp -v .config /boot/config-$FV
cp -v System.map /boot/System.map-$FV
cp -v arch/x86/boot/bzImage /boot/vmlinuz-$FV

# setup /usr/src directory as required
if [ ! -e "$FVDIR" ]; then
	# kernel source is somewhere else!
	# link /usr/src/linux-$FV to REALPWDIR
	ln -vfs "$REALPWDIR" "$FVDIR"
fi

# remove and recreate linux link to PWD

ln -vnfs "$FVDIR" /usr/src/linux

echo "Performing mkinitrd"

/sbin/mkinitrd -F /etc/mkinitrd.conf -k $FV -o /boot/initrd-$FV.gz

echo "Be sure to adjust and run lilo, or edit grub.cfg"
