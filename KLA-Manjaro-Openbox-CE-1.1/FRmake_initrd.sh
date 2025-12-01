#!/bin/bash
progname="FRmake_initrd.sh"; version="1.0.0"; revision="-rc1"
# Creation Date: 02Nov2022; Revision Date: 02Nov2022
# Copyright wiak (William McEwan) 02Nov2022+; Licence MIT (aka X11 license) 
# Inspired by "Create initramfs image" by fredx181 2021-09-07
# Main dependency: FRmake_initrd_dep.sh, which is a minor fork
# of "initramfs_create" (C) Tomas M <http://www.linux-live.org/>
# Includes code from firstribit.sh, and modify_initrd.sh (C) wiak

INITCOMPR=gzip

_get_FR_initrd (){
  wget -c --no-check-certificate https://owncloud.rockedge.org/index.php/s/HRZhsnouSm3Gpf3/download -O modify_initrd_gz.sh && chmod +x modify_initrd_gz.sh
  wget -c --no-check-certificate https://owncloud.rockedge.org/index.php/s/CXixDo8Dd2rtxSQ/download -O initrd-latest.gz
  wget -c --no-check-certificate https://owncloud.rockedge.org/index.php/s/8aFjxy5QrjfyI8o/download -O w_init
}

case "$1" in
	'') printf "initrd name must be specified\n";exit;;
	'--version') printf "$progname ${version}${revision}\n"; exit 0;;
	'-h'|'--help'|'-?') printf "Run this script from location of compressed initrd with command:
  $progname <initrd filename | latest> <main root_filesystem dirname> [xz|zst]
  If no third argument provided, gz is used for final initrd compression
  For example: ./FRmake_initrd.sh latest firstrib_rootfs xz\n";exit 0;;
	"-*") printf "option $1 not available\n";exit 0;;
esac

# Skeleton initrd-latest is stored gz compressed 
[ "$3" = "" ] && compression_out="gz" || compression_out="$3"

if [ "$1" = "latest" ];then
  _get_FR_initrd
  initramfs="initrd-latest.gz"
  initrd="initrd-latest"
else
  initramfs="$1"
  initrd=${1%.*}
fi

mkdir -p ${initrd}_decompressed
cd ${initrd}_decompressed
zcat ../${initramfs} | cpio -idm
cd ..
sync;sync
[ -d "$2" ] && rootfs="$2" || rootfs=firstrib_rootfs
kernel2use=`ls -1 "${rootfs}"/lib/modules | tail -1` # -1 hopefully makes LMK use most recent kernel if many installed in rootfs

export LMK="lib/modules/${kernel2use}"; echo LMK is "$LMK"
./FRmake_initrd_dep.sh ${initrd}_decompressed $compression_out "$rootfs"  # where initrd $compression_out is gz|xz|zst
exit 0
