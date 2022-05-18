#!/bin/sh
# program to install a kernel
# Peter Hyman, pete@peterhyman.com
# No warranties, and free to use and copy
# utility functions

# will use getopt to determine build criteria
# and then order the options properly to produce
# kernel.

# set -x	# for debugging

# set constants for system
NICE=$(which nice 2>/dev/null)
MAKE=$(which make 2>/dev/null)
MAKEOPTS="-j8"
MAKECMD="$NICE $MAKE"
BOOTDIR="/boot"
EFIDIR="/boot/efi/EFI/Slackware"

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

error() {
	outp "ERROR: $1"
	fini 1
}

# do some checks
[ $UID -ne 0 ] && error "Must run as root to install a kernel."
[ ! -x $(which make) ] && error "SERIOUS ERROR: No make command found!"
[ ! -f .config ] && error "No .config file found. Run make oldconfig."
[ ! -f Makefile ] && error "SERIOUS ERROR: No Makefile file found."
[ ! -x $(which mkinitrd) ] && error "mkinitrd not found. This may be serious."
[ ! -x $(which depmod) ] && error "depmod program not found. Using sudo?"

usage() {
	outp "$(basename $0) usage

$(basename $0) [options]
none	- 	do everything from make olddefconfig to mkinitrd
-k	-	use make kernelversion
-K	-	use make kernelrelease
-m	-	make all
  -ma	-	make all
  -mo	-	make oldconfig
  -mO	-	make olddefconfig
  -mr	-	make mrproper
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

# get options, taken from util-linux doc

TEMP=$(getopt -o 'kKm::CELh' -- "$@")
if [ $? -ne 0 ]; then
	usage
	fini 1
fi

# break up TEMP into positional parameters

eval set -- "$TEMP"
unset TEMP

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
	outp "Kernel Release Version is $FV"
# not used currently
#	KV=`echo $FV | cut -d . -f 1`
#	PL=`echo $FV | cut -d . -f 2`
#	SL=`echo $FV | cut -d . -f 3`
}

setupvars() {
	# Set some directories and detect any links
	# getkv or getkr must be called prior to get kernel version value $FV
	[ -z "$FV" ] && getkv
	REALPWDIR=`realpath .`
	USRDIR="/usr"
	USRSRCDIR="$USRDIR/src"
	FVDIR="$USRSRCDIR/linux-$FV"
	[ "$PWD" != "$REALPWDIR" ] && cd "$REALPWDIR"
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
	$MAKECMD $MAKEOPTS vmlinux || error "make vmlinux failed."
}

makebz() {
	outp "performing make bzimage"
	$MAKECMD $MAKEOPTS bzImage || error "make bzimage failed."
}

makem() {
	outp "performing make modules"
	$MAKECMD $MAKEOPTS modules || error "make modules failed."
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

# set all variables to no
MAKEKV=no
MAKEKR=no
MAKEMRP=no
MAKEC=no
MAKEA=no
MAKEOC=no
MAKEODC=no
MAKEV=no
MAKEBZ=no
MAKEM=no
MAKEMI=no
MAKEHI=no
MAKEIRD=no
COPYB=no
COPYE=no
LINKSRC=no

# if last option is not "--" then go through all cases
if [ "$1" != "--" ]; then
while true; do
	case "$1" in
		'-k')	# get kernel version
			MAKEKV=yes
			MAKEKR=no
			MAKEA=no
			shift
			continue
			;;
		'-K')	# get kernel release verion
			MAKEKV=no
			MAKEKR=yes
			MAKEA=no
			shift
			continue
			;;
		'-m')	# make all or make with specific options
			case "$2" in
				'' | 'a' )
					MAKEA=yes
					;;
				'o')	# oldconfig
					MAKEODC=no
					MAKEOC=yes
					MAKEA=no
					;;
				'O')	# olddefconfig
					MAKEODC=yes
					MAKEOC=no
					MAKEA=no
					;;
				'r')	# mrproper
					MAKEMRP=yes
					MAKEC=no
					MAKEKV=no
					MAKEKR=no
					MAKEODC=no
					MAKEOC=no
					MAKEA=no
					;;
				'c')	# clean
					MAKEMRP=no
					MAKEC=yes
					MAKEKV=no
					MAKEKR=no
					MAKEODC=no
					MAKEOC=no
					MAKEA=no
					;;
				'v')	# vmlinux
					MAKEV=yes
					MAKEA=no
					;;
				'b')	# bzImage
					MAKEBZ=yes
					MAKEA=no
					;;
				'm')	# modules
					MAKEM=yes
					MAKEA=no
					;;
				'M')	# modules_install
					MAKEMI=yes
					MAKEA=no
					;;
				'h')	# headers_install
					MAKEHI=yes
					MAKEA=no
					;;
				'i')	# initrd
					MAKEIRD=yes
					MAKEA=no
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
			COPYB=yes
			MAKEA=no
			shift
			continue
			;;
		'-E')	# copy to efi partition
			COPYE=yes
			MAKEA=no
			shift
			continue
			;;
		'-L')	# link /usr/src/linux to kernel dir
			LINKSRC=yes
			MAKEA=no
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
elif [ "$1" == "--" ]; then	# no arguments, set defaults
	MAKEA=yes
	MAKEODC=yes
	MAKEKV=yes
	shift
fi	# if arguments

# it's still possible non options are present. We then have to stop as well
if [ "$1" ]; then
	output="$@"
	error "Extraneous arguments: $output"
fi

# now process everything in order optionally
# need kernel version first all the time
[ $MAKEKV == yes  ]	&& getkv
[ $MAKEKR == yes  ]	&& getkr
# if kernel version not set, it will be in setupvars
setupvars

[ $MAKEMRP == yes ]	&& makemrp
[ $MAKEODC == yes ]	&& makeodc
[ $MAKEOC == yes ]	&& makeoc
[ $MAKEC == yes ]	&& makec
[ $MAKEV == yes   -o $MAKEA == yes ]	&& makev
[ $MAKEBZ == yes  -o $MAKEA == yes ]	&& makebz
[ $MAKEM == yes   -o $MAKEA == yes ]	&& makem
[ $MAKEMI == yes  -o $MAKEA == yes ]	&& makemi
[ $MAKEHI == yes  -o $MAKEA == yes ]	&& makehi
[ $MAKEIRD == yes -o $MAKEA == yes ]	&& makeird
[ $COPYB == yes   -o $MAKEA == yes ]	&& copy2boot
[ $COPYE == yes   -o $MAKEA == yes ]	&& copy2efi
[ $LINKSRC == yes -o $MAKEA == yes ]	&& dolinks

fini 0
