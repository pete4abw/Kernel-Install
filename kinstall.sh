#!/bin/sh
# program to install a kernel
# Peter Hyman, pete@peterhyman.com
# No warranties, and free to use and copy
# utility functions

# will use getopt to determine build criteria
# and then order the options properly to produce
# kernel.

# set -x	# for debugging
# save current directory

pushd $PWD

# return to original dir if needed
# exit with error code set
fini() {
	popd
	exit $1
}

outp() {
	echo "$1"
}

usage() {
	outp "$(basename $0) usage

$(basename $0) [options]
none	- 	do everything from make olddefconfig to mkinitrd
-k	-	use make kernelversion
-K	-	use make kernelrelease
-m	-	make all
  -ma	-	make all
  -mo	-	make oldconfig
  -md	-	make olddefconfig
  -mp	-	make mrproper
  -mc	-	make clean
  -mv	-	make vmlinuz
  -mb	-	make bzimage
  -mm	-	make modules
  -mM	-	make modules_install
  -mh	-	make headers_install
  -mi	-	make initrd
  -C	-	perform files copy to boot
  -E	-	perform copy files to EFIDIR
  -L	-	symlink /usr/src to REALPWD
-h	-	show this help and exit"
return
}

error() {
	outp "ERROR: $1"
	fini 1
}

# get options, taken from util-linux doc

TEMP=$(getopt -o 'kKm::CELh' -- "$@")
if [ $? -ne 0 ]; then
	usage
	fini 1
fi

# break up TEMP into positional parameters

eval set -- "$TEMP"
unset TEMP

# do some checks
[ $UID -ne 0 ] && error "Must run as root to install a kernel."
[ ! -x $(which make) ] && error "SERIOUS ERROR: No make command found!"
[ ! -f .config ] && error "No .config file found. Run make oldconfig."
[ ! -f Makefile ] && error "SERIOUS ERROR: No Makefile file found."
[ ! -x $(which mkinitrd) ] && error "mkinitrd not found. This may be serious."
[ ! -x $(which depmod) ] && error "depmod program not found. Using sudo?"

setupvars() {
	# Set some directories and detect any links
	# getkv or getkr must be called prior to get kernel version value $FV
	BOOTDIR="/boot"
	EFIDIR="/boot/efi/EFI/Slackware"
	MAKEOPTS="-j8"
	REALPWDIR=`realpath .`
	USRDIR="/usr"
	USRSRCDIR="$USRDIR/src"
	FVDIR="$USRSRCDIR/linux-$FV"
	[ "$PWD" != "$REALPWDIR" ] && cd "$REALPWDIR"
}

getkv() {
	FV=$(make kernelversion | tail -n1) || error "cannot fetch kernel version."
	outp "Kernel Version is $FV"
# not used currently
#	KV=`echo $FV | cut -d . -f 1`
#	PL=`echo $FV | cut -d . -f 2`
#	SL=`echo $FV | cut -d . -f 3`
}

getkr() {
	FV=$(make kernelrelease | tail -n1) || error "cannot fetch kernel release."
	outp "Kernel Version is $FV"
# not used currently
#	KV=`echo $FV | cut -d . -f 1`
#	PL=`echo $FV | cut -d . -f 2`
#	SL=`echo $FV | cut -d . -f 3`
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

makebz() {
	outp "performing make bzimage"
	$NICE $NICENESS make $MAKEOPTS bzImage || error "make bzimage failed."
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
	outp "Be sure to adjust and run lilo, or edit grub.cfg"

}

makeall() {
	outp "performing make all"
	makev
	makebz
	makem
	makemi
	makehi
	makeird
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

dolinks() {
	# setup /usr/src directory as required
	echo "Linking /usr/src/linux to $REALPWDIR"
	if [ ! -e "$FVDIR" ]; then
		# kernel source is somewhere else!
		# link /usr/src/linux-$FV to REALPWDIR
		ln -vfs "$REALPWDIR" "$FVDIR"
	fi

	# remove and recreate linux link to PWD
	ln -vnfs "$FVDIR" /usr/src/linux
}

# set all variables to false
MAKEKV=false
MAKEKR=false
MAKEMRP=false
MAKEC=false
MAKEA=false
MAKEOC=false
MAKEODC=false
MAKEV=false
MAKEBZ=false
MAKEM=false
MAKEMI=false
MAKEHI=false
MAKEIRD=false
COPYB=false
COPYE=false
LINKSRC=false

# if last option is not "--" then go through all cases
if [ $1 != "--" ]; then
while true; do
	case "$1" in
		'-k')	# get kernel version
			MAKEKV=true
			MAKEKR=false
			MAKEA=false
			shift
			continue
			;;
		'-K')	# get kernel release verion
			MAKEKV=false
			MAKEKR=true
			MAKEA=false
			shift
			continue
			;;
		'-m')	# make all or make with specific options
			case "$2" in
				'' | 'a' )
					MAKEA=true
					;;
				'o')	# oldconfig
					MAKEODC=false
					MAKEOC=true
					MAKEA=false
					;;
				'd')	# olddefconfig
					MAKEODC=true
					MAKEOC=false
					MAKEA=false
					;;
				'p')	# mrproper
					MAKEMRP=true
					MAKEC=false
					MAKEKV=false
					MAKEKR=false
					MAKEODC=false
					MAKEOC=false
					MAKEA=false
					;;
				'c')	# clean
					MAKEMRP=false
					MAKEC=true
					MAKEKV=false
					MAKEKR=false
					MAKEODC=false
					MAKEOC=false
					MAKEA=false
					;;
				'v')	# vmlinux
					MAKEV=true
					MAKEA=false
					;;
				'b')	# bzImage
					MAKEBZ=true
					MAKEA=false
					;;
				'm')	# modules
					MAKEM=true
					MAKEA=false
					;;
				'M')	# modules_install
					MAKEMI=true
					MAKEA=false
					;;
				'h')	# headers_install
					MAKEHI=true
					MAKEA=false
					;;
				'i')	# initrd
					MAKEIRD=true
					MAKEA=false
					;;
				*)	# oops
					outp "Invalid Make Option $2"
					usage
					fini 1
					;;
			esac
			shift 2
			continue
			;;
		'-C')	# copy to /boot
			COPYB=true
			MAKEA=false
			shift
			continue
			;;
		'-E')	# copy to efi partition
			COPYE=true
			MAKEA=false
			shift
			continue
			;;
		'-L')	# link /usr/src/linux to kernel dir
			LINKSRC=true
			MAKEA=false
			shift
			continue
			;;
		'-h')	# show help
			usage
			fini 0
			;;
		'--')	# last option
			shift
			break
			;;
		*)	# should never get here
			outp "Unknown option $1"
			usage
			fini 1
			;;
	esac
done
elif [ $1 == "--" ]; then	# no arguments, set defaults
	MAKEA=true
	MAKEODC=true
	MAKEKV=true
fi	# if arguments

# it's still possible non options are present. We then have to stop as well
if [ $1 ]; then
	output="$@"
	error "Extraneous arguments: $output"
fi

# now process everything in order optionally
# need kernel version first all the time
[ $MAKEKV==true ]	&& getkv
[ $MAKEKR==true ]	&& getkr

setupvars

[ $MAKEMRP==true ]	&& makemrp
[ $MAKEODC==true ]	&& makeodc
[ $MAKEOC==true ]	&& makeoc
[ $MAKEC==true ]	&& makec
[ $MAKEV==true   || $MAKEA==true ]	&& makev
[ $MAKEBZ==true  || $MAKEA==true ]	&& makebz
[ $MAKEM==true   || $MAKEA==true ]	&& makem
[ $MAKEMI==true  || $MAKEA==true ]	&& makemi
[ $MAKEHI==true  || $MAKEA==true ]	&& makehi
[ $MAKEIRD==true || $MAKEA==true ]	&& makeird
[ $COPYB==true   || $MAKEA==true ]	&& copy2boot
[ $COPYE==true   || $MAKEA==true ]	&& copy2efi
[ $LINKSRC==true || $MAKEA==true ]	&& dolinks

fini 0
