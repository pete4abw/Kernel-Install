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
USRDIR="/usr"
USRSRCDIR="$USRDIR/src"
BOOTDIR="/boot"
EFIDIR="/boot/efi/EFI/Slackware"
PWDIR=$PWD
REALPWDIR=`realpath .`

# unusual but possible. If we start in /usr/src/linux, we
# need to change to the real directory so we can set links
# later
[ "$PWDIR" != "$REALPWDIR" ] && cd "$REALPWDIR"

### make block ###
# comment out or alter as desired
# set up .config file with defaults
make olddefconfig
# make with -j8 option
make -j8
# install modules
make modules_install
# install headers to /usr
make headers_install INSTALL_HDR_PATH="$USRDIR"

# use kernel.release to get version if it exists
# KR = Kernel Release
# PL = Patch Level
# SL = Patch Sub Level
# FV = Final Version
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

FVDIR="$USRSRCDIR/linux-$FV"

# setup /usr/src directory as required
echo "Linking /usr/src/linux to $REALPWDIR"
if [ ! -e "$FVDIR" ]; then
	# kernel source is somewhere else!
	# link /usr/src/linux-$FV to REALPWDIR
	ln -vfs "$REALPWDIR" "$FVDIR"
fi

# remove and recreate linux link to PWD
ln -vnfs "$FVDIR" /usr/src/linux

### mkinitrd ###
# be sure mkinitrd.conf is set
echo "Performing mkinitrd"

/sbin/mkinitrd -F /etc/mkinitrd.conf -k $FV -o /boot/initrd-$FV.gz

### Install initrd and vmlinus ###
echo "Copying core files to /boot"
cp -v .config /boot/config-$FV
cp -v System.map /boot/System.map-$FV
cp -v arch/x86/boot/bzImage /boot/vmlinuz-$FV

# Copy files to efi dir
# adjust as needed
echo "Copying files to efi"
cp -v "$BOOTDIR"/initrd-$FV.gz "$EFIDIR"/initrd.gz
cp -v "$BOOTDIR"/vmlinuz-$FV "$EFIDIR"/vmlinuz

echo "Be sure to adjust and run lilo, or edit grub.cfg"

