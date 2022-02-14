#!/bin/sh
# program to install a kernel
# Peter Hyman, pete@peterhyman.com
# No warranties, and free to use and copy

#save CD
pushd $PWD

# utility functions
outp() {
	echo "$1"
}

error() {
	outp "ERROR: $1"
	popd
	exit 1
}

setupvars() {
	# do some checks
	[ $UID -ne 0 ] && error "Must run as root to install a kernel."
	[ ! -x $(which make) ] && error "SERIOUS ERROR: No make command found!"
	[ ! -f .config ] && error "No .config file found. Run make oldconfig."
	[ ! -f Makefile ] && error "SERIOUS ERROR: No Makefile file found."
	[ ! -x $(which mkinitrd) ] && error "mkinitrd not found. This may be serious."
	[ ! -x $(which depmod) ] && error "depmod program not found. Using sudo?"

	# Set some directories and detect any links
	BOOTDIR="/boot"
	EFIDIR="/boot/efi/EFI/Slackware"
	MAKEOPTS="-j8"
	PWDIR=$PWD
	REALPWDIR=`realpath .`
	USRDIR="/usr"
	USRSRCDIR="$USRDIR/src"
	# Check for nice
	NICE=$(which nice)
	NICENESS=

	if [ -x $NICE ]; then
		# update niceness if desired
		NICENESS="-n 19"
	else
		NICE=
	fi
}


getkv() {
	FV=$(make kernelversion | tail -n1) || error "cannot fetch kernel version."
	outp "Kernel Version is $FV"
	KV=`echo $FV | cut -d . -f 1`
	PL=`echo $FV | cut -d . -f 2`
	SL=`echo $FV | cut -d . -f 3`
}

getkr() {
	FV=$(make kernelrelease | tail -n1) || error "cannot fetch kernel release."
	outp "Kernel Version is $FV"
	KV=`echo $FV | cut -d . -f 1`
	PL=`echo $FV | cut -d . -f 2`
	SL=`echo $FV | cut -d . -f 3`
}

makemrp() {
	outp "performing make mrproper"
	make mrproper ||  error "make mrproper failed."
}

makec() {
	outp "performing make clean"
	make clean
}

makeoc() {
	outp "performing make oldconfig"
	make oldconfig || error "make oldconfig failed."
}

makeodc() {
	outp "performing make olddefconfig"
	make olddefconfig || error "make olddefconfig failed."
}

makev() {
	outp "performing make vmlinux"
	$NICE $NICENESS make $MAKEOPTS vmlinux || error "make vmlinux failed."
}

makem() {
	outp "performing make modules"
	$NICE $NICENESS make $MAKEOPTS modules || error "make modules failed."
}

makemi() {
	outp "performing make modules_install"
	make modules_install || error "make modules_install failed."
}

makehi() {
	outp "performing make headers_install"
	make headers_install INSTALL_HDR_PATH="$USRDIR" || error "installing headers failed."
}

makeird() {
	outp "Performing mkinitrd"
	mkinitrd -F /etc/mkinitrd.conf -k $FV -o /boot/initrd-$FV.gz
}

makeall() {
	outp "performing make all"
	makeodc
	# makeoc
	makev
	makem
	makemi
	makehi
}

copy2boot() {
	outp "Copying core files to /boot"
	cp -v .config /boot/config-$FV || error "copying config to boot"
	cp -v System.map /boot/System.map-$FV || error "copying System.map to boot"
	cp -v arch/x86/boot/bzImage /boot/vmlinuz-$FV || error "copying vmlinux to boot"
}

copy2efi() {
	outp "Saving initrd and vmlunz in efi"
	if [ -r "$EFIDIR"/initrd.gz ]; then
		mv -v "$EFIDIR"/initrd.gz "$EFIDIR"/initrd-lastgood.gz
	fi
	if [ -r "$EFIDIR"/vmlinuz ]; then
		mv -v "$EFIDIR"/vmlinuz "$EFIDIR"/vmlinuz-lastgood
	fi
	outp "Copying files to efi"
	cp -v "$BOOTDIR"/initrd-$FV.gz "$EFIDIR"/initrd.gz
	cp -v "$BOOTDIR"/vmlinuz-$FV "$EFIDIR"/vmlinuz
}

# unusual but possible. If we start in /usr/src/linux, we
# need to change to the real directory so we can set links
# later
[ "$PWDIR" != "$REALPWDIR" ] && cd "$REALPWDIR"

setupvars
getkv
# getkr
# makemrp
# makec
makeall
#makeodc
#makeoc
#makev
#makem
#makemi
#makehi
#makeird
copy2boot
copy2efi

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

echo "Be sure to adjust and run lilo, or edit grub.cfg"

# back to initial directory
popd
