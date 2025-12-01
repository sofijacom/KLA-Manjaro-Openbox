#!/bin/bash
progname="FRextract_kernel.sh"; version="1.0.0"; revision="-rc1"
# This is mainly tiny part of a routine extracted from "initramfs_create" (C) Tomas M; # License: GPL2
# https://github.com/Tomas-M/linux-live/blob/master/initramfs/initramfs_create
# plug a few extras by fredx181 and wiak

trap default INT TERM ERR EXIT

default (){
 echo in trap default function
 # clean up temporary symlink to firstrib_rootfs kernel modules
 [ -L "/lib/modules/$KERNEL" ] && rm -f "/lib/modules/$KERNEL" #fredx181
 cd "$run_dir"
 exit
}

### wiak option processing
case "$1" in
	'--version') printf "$progname ${version}${revision}\n"; exit 0;;
	'-h'|'--help'|'-?') printf "Run this script from location of uncompressed root filesystem using:
  ./${progname} <uncompressed_rootfs_dirname>
  Alternatively, run from location of unsquashed modules.sfs using:
  ./${progname} <unsquashed_modules_dirname>
  For example: ./FRextract_kernel.sh firstrib_rootfs\n";exit 0;;
	"-*") printf "option $1 not available\n";exit 0;;
esac
[ -d "$1" ] && root_fs="$1" || root_fs=firstrib_rootfs
if [ ! -d "$root_fs" ];then printf "Specified root filesystem needs to be a directory. Exiting...\n";exit 0;fi

if [ -d "${root_fs}"/lib/modules ];then #wiak
  kernel2use=`ls -1 "${root_fs}"/lib/modules | tail -1` # -1 hopefully makes LMK use most recent kernel if many installed in root_fs lib/modules
  LMK="lib/modules/${kernel2use}"; echo LMK is "$LMK"
  depm_base="${root_fs}"
else
  kernel2use=`ls -1 "${root_fs}"/usr/lib/modules | tail -1`
  LMK="usr/lib/modules/${kernel2use}"; echo LMK is "$LMK"
  depm_base="${root_fs}/usr"
fi

KERNEL=`basename "$LMK"`
run_dir="$PWD"
datestamp=`date +%Y_%m_%d_%H%M%S`
echo root_fs is ${root_fs:-none specified} KERNEL is ${KERNEL:-none specified}

### per fredx181 cr-debkernel script
# Making link on host system lib/modules to where firstrib_rootfs modules are
[ ! -f "/lib/modules/$KERNEL/modules.alias" ] && ln -sf "${run_dir}"/"${root_fs}"/"${LMK}" "/lib/modules/$KERNEL"

### From initramfs_create by Thomas M
find $root_fs -name "*.ko.gz" -exec gunzip {} \;
find $root_fs -name "*.ko.xz" -exec unxz {} \; #wiak
find $root_fs -name "*.ko.zst" -exec zstd -d --rm {} \; #wiak

depmod -b "${depm_base}" $KERNEL
[ -L "/lib/modules/$KERNEL" ] && rm -f "/lib/modules/$KERNEL" #fredx181

# Extract modules and produce 00modules sfs
mkdir -p "${run_dir}"/modules${datestamp}/usr/lib/modules && mv "${run_dir}"/"${root_fs}"/"${LMK}" "${run_dir}"/modules${datestamp}/usr/lib/modules

# extract kernel to frugal bootdir
echo "Can usually ignore error if vmlinuz does not exist:"
mv "${run_dir}"/"${root_fs}"/boot/vmlinuz* .

printf "\nFinished. modules${datestamp} directory created and kernel extracted
You can now create a squashed fs from modules${datestamp} if you wish\n"

exit 0
