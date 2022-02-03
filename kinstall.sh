#!/bin/sh
# program to install a kernel
# Peter Hyman, pete@peterhyman.com
# No warranties, and free to use and copy

error() {
	echo "$1"
	exit 1
}

# do some checks
[ $UID -ne 0 ] && error "Must run as root to install a kernel."
[ ! -x $(which make) ] && error "SERIOUS ERROR: No make command found!"
[ ! -f .config ] && error "No .config file found. Run make oldconfig."
[ ! -f Makefile ] && error "SERIOUS ERROR: No Makefile file found."
[ ! -x $(which mkinitrd) ] && error "mkinitrd not found. This may be serious."
[ ! -x $(which depmod) ] && error "depmod program not found. Using sudo?"

# Check for nice
NICE=$(which nice)
if [ -x $NICE ]; then
	# update niceness if desired
	NICENESS="-n 19"
else
	unset NICE
	unset NICENESS
fi
# set make options if desired
MAKEOPTS="-j8"

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
# or change to `make oldconfig` and input new options manually.`
echo "making oldconfig"
make olddefconfig
[ $? -ne 0 ] && error "Error running make olddefconfig."
# make with -j8 option
# can split up with
# make vmlinux
# make modules
# instead of make all which is default
echo "making kernel and modules: $NICE $NICENESS make $MAKEOPTS"
$NICE $NICENESS make $MAKEOPTS
[ $? -ne 0 ] && error "Error making kernel."
# install modules
echo "installing modules"
$NICE $NICENESS make modules_install
[ $? -ne 0 ] && error "Error installing modules."
# install headers to /usr
echo "installing headers"
$NICE $NICENESS make headers_install INSTALL_HDR_PATH="$USRDIR"
[ $? -ne 0 ] && error "Error installing headers."

# PL = Patch Level
# SL = Patch Sub Level
# FV = Final Version
# use make to get either kernelversion or kernelrelease
# it's possible make throws an error before printing the version, so
# get the last line only.
# FV=$(make kernelrelease | tail -n1)
FV=$(make kernelversion | tail -n1)
[ $? -ne 0 ] &&  error "Error fetching kernel version."

echo "Kernel Version is $FV"
KV=`echo $FV | cut -d . -f 1`
PL=`echo $FV | cut -d . -f 2`
SL=`echo $FV | cut -d . -f 3`

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

$NICE $NICENESS mkinitrd -F /etc/mkinitrd.conf -k $FV -o /boot/initrd-$FV.gz

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
