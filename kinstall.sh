#!/bin/sh
# program to install a kernel
# Peter Hyman, pete@peterhyman.com
# No warranties, and free to use and copy

error() {
	echo "$1"
	exit 1
}

# do some checks
[ $UID -ne 0 ] && error "Must run as root to install a kernel"
[ ! -f .config ] && error "No .config file found"
[ ! -f Makefile ] && error "No Makefile file found"
[ ! $(which depmod) ] && error "depmod program not found. Using sudo?"

# Set some directories and detect any links
USDIR="/usr/src"
PWDIR=$PWD
REALPWDIR=`realpath .`

# unusual but possible. If we start in /usr/src/linux, we
# need to change to the real directory so we can set links
# later
[ "$PWDIR" != "$REALPWDIR" ] && cd "$REALPWDIR"

# use kernel.release to get version if it exists
if [ -r include/config/kernel.release ] ; then
	KR=`cat include/config/kernel.release`
	KV=`echo $KR | cut -d . -f 1`
	PL=`echo $KR | cut -d . -f 2`
	SL=`echo $KR | cut -d . -f 3`
else
# Kernel, Patch, Sublevel, and full kernel version
# set from Makefile
	KV=`grep -m 1 "VERSION"		Makefile | cut -d ' ' -f 3`
	PL=`grep -m 1 "PATCHLEVEL"	Makefile | cut -d ' ' -f 3`
	SL=`grep -m 1 "SUBLEVEL"	Makefile | cut -d ' ' -f 3`
fi

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

