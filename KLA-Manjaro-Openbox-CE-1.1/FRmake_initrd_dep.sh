#!/bin/bash
progname="FR_crinitrd.sh"; version="1.0.0"; revision="-rc1"
# This is a minor extract/fork of "initramfs_create" (C) Tomas M; # License: GPL2
# https://github.com/Tomas-M/linux-live/blob/master/initramfs/initramfs_create

run_dir="$PWD"
INITRAMFS="$1"
KERNEL=`basename "$LMK"`
echo INITRAMFS is ${INITRAMFS:-none specified} compression is ${2:-none specified} KERNEL is ${KERNEL:-none specified}
NETWORK="true"

trap default INT TERM ERR EXIT

default (){
 echo in trap default function
 # clean up temporary symlink to firstrib_rootfs kernel modules
 [ -L "/lib/modules/$KERNEL" ] && rm -f "/lib/modules/$KERNEL"
 cd "$run_dir"
 rm -rf "$INITRAMFS"
 rm initrd-latest.gz
 exit
}

# wiak option processing
case "$1" in
	'') printf "initrd_decompressed directory name must be specified\n";exit;;
	'--version') printf "$progname ${version}${revision}\n"; exit 0;;
	'-h'|'--help'|'-?') printf "Run this script from location of decompressed initrd with command:
  ./${progname} <initrd_decompressed_dirname> [gz|xz|zst]
  For example: ./FR_crinitrd.sh initrd_decompressed xz\n";exit 0;;
	"-*") printf "option $1 not available\n";exit 0;;
esac
if [ ! -d "$1" ];then printf "decompressed initrd directory must be specified - exiting...\n";exit 0;fi

### per fredx181 cr-debkernel script
# Making link on host system lib/modules to where firstrib_rootfs modules are
[ ! -f "/lib/modules/$KERNEL/modules.alias" ] && ln -sf "${run_dir}"/"$3"/lib/modules/$KERNEL "/lib/modules/$KERNEL" 2> /dev/null

### START extract from Thomas M initramfs_create (with very minor mods/additions)
# copy file to initramfs tree, including
# all library dependencies (as shown by ldd)
# $1 = file to copy (full path)
copy_including_deps()
{
   # if source doesn't exist or target exists, do nothing
   # Thomas M orig was:   if [ ! -e "$1" -o -e "$INITRAMFS"/"$1" ]; then
   if [ ! -e "$1" ]; then  # wiak 07Jan2023S
      return
   fi

   cp -R --parents "$1" "$INITRAMFS"
   if [ -L "$1" ]; then
      DIR="$(dirname "$1")"
      LNK="$(readlink "$1")"
      copy_including_deps "$(cd "$DIR"; realpath -s "$LNK")"
   fi

   ldd "$1" 2>/dev/null | sed -r "s/.*=>|[(].*//g" | sed -r "s/^\\s+|\\s+\$//" \
     | while read LIB; do
        copy_including_deps "$LIB"
     done

   for MOD in $(find "$1" -type f | grep .ko); do
      for DEP in $(cat /$LMK/modules.dep | fgrep /$(basename $MOD):); do
         copy_including_deps "/$LMK/$DEP"
      done
   done

   shift
   if [ "$1" != "" ]; then
       copy_including_deps "$@"
   fi
}

rm -Rf ${INITRAMFS}/lib/modules/* 

mknod $INITRAMFS/dev/console c 5 1
mknod $INITRAMFS/dev/null c 1 3
mknod $INITRAMFS/dev/ram0 b 1 0
mknod $INITRAMFS/dev/tty1 c 4 1
mknod $INITRAMFS/dev/tty2 c 4 2
mknod $INITRAMFS/dev/tty3 c 4 3
mknod $INITRAMFS/dev/tty4 c 4 4

#copy_including_deps /usr/bin/strace
#copy_including_deps /usr/bin/lsof

copy_including_deps /$LMK/kernel/fs/aufs
copy_including_deps /$LMK/kernel/fs/overlayfs
copy_including_deps /$LMK/kernel/fs/ext2
copy_including_deps /$LMK/kernel/fs/ext3
copy_including_deps /$LMK/kernel/fs/ext4
copy_including_deps /$LMK/kernel/fs/fat
copy_including_deps /$LMK/kernel/fs/nls
copy_including_deps /$LMK/kernel/fs/fuse
copy_including_deps /$LMK/kernel/fs/isofs
#copy_including_deps /$LMK/kernel/fs/9p #wiak experiments only
#copy_including_deps /$LMK/kernel/net/9p #wiak experiments only
copy_including_deps /$LMK/kernel/fs/ntfs
copy_including_deps /$LMK/kernel/fs/ntfs3
copy_including_deps /$LMK/kernel/fs/reiserfs
copy_including_deps /$LMK/kernel/fs/squashfs
copy_including_deps /$LMK/kernel/crypto # fredx181 of Puppy Linux forum
copy_including_deps /$LMK/kernel/fs/exfat # fredx181
copy_including_deps /$LMK/kernel/fs/btrfs # fredx181

# crc32c is needed for ext4, but I don't know which one, add them all, they are small
find /$LMK/kernel/ | grep crc32c | while read LINE; do
   copy_including_deps $LINE
done

copy_including_deps /$LMK/kernel/drivers/staging/zsmalloc # needed by zram
copy_including_deps /$LMK/kernel/drivers/block/zram
copy_including_deps /$LMK/kernel/drivers/block/loop.*

# usb drivers
copy_including_deps /$LMK/kernel/drivers/usb/storage/usb-storage.*
copy_including_deps /$LMK/kernel/drivers/usb/storage/uas.* # fredx181
copy_including_deps /$LMK/kernel/drivers/usb/host
copy_including_deps /$LMK/kernel/drivers/usb/common
copy_including_deps /$LMK/kernel/drivers/usb/core
copy_including_deps /$LMK/kernel/drivers/hid/usbhid
copy_including_deps /$LMK/kernel/drivers/hid/hid.*
copy_including_deps /$LMK/kernel/drivers/hid/uhid.*
copy_including_deps /$LMK/kernel/drivers/hid/hid-generic.*

# disk and cdrom drivers
copy_including_deps /$LMK/kernel/drivers/cdrom
copy_including_deps /$LMK/kernel/drivers/scsi/sr_mod.*
copy_including_deps /$LMK/kernel/drivers/scsi/sd_mod.*
copy_including_deps /$LMK/kernel/drivers/scsi/scsi_mod.*
copy_including_deps /$LMK/kernel/drivers/scsi/sg.*
copy_including_deps /$LMK/kernel/drivers/ata
copy_including_deps /$LMK/kernel/drivers/nvme
copy_including_deps /$LMK/kernel/drivers/mmc
copy_including_deps /$LMK/kernel/drivers/md # fredx181
copy_including_deps /$LMK/kernel/drivers/pcmcia # wiak 12Jan2023

# network support drivers
if [ "$NETWORK" = "true" ]; then
   # add all known ethernet drivers
   copy_including_deps /$LMK/kernel/drivers/net/phy/realtek.* # fredx181
   copy_including_deps /$LMK/kernel/drivers/net/ethernet
   copy_including_deps /$LMK/kernel/fs/nfs # fredx181
fi

# copy all custom-built modules
copy_including_deps /$LMK/updates

copy_including_deps /$LMK/modules.*


find $INITRAMFS -name "*.ko.gz" -exec gunzip {} \;
find $INITRAMFS -name "*.ko.xz" -exec unxz {} \; # wiak
find $INITRAMFS -name "*.ko.zst" -exec zstd -d --rm {} \; # wiak

# trim modules.order file. Perhaps we could remove it entirely
MODULEORDER="$(cd "$INITRAMFS/$LMK/"; find -name "*.ko" | sed -r "s:^./::g" | tr "\n" "|" | sed -r "s:[.]:.:g")"
cat $INITRAMFS/$LMK/modules.order | sed -r "s/.ko.gz\$/.ko/" | sed -r "s/.ko.xz\$/.ko/" | sed -r "s/.ko.zst\$/.ko/" | grep -E "$MODULEORDER"/foo/bar > $INITRAMFS/$LMK/_ # wiak xz and zst addition
mv $INITRAMFS/$LMK/_ $INITRAMFS/$LMK/modules.order

depmod -b $INITRAMFS $KERNEL

cd $INITRAMFS
case $2 in  #wiak: providing extra compression choices than xz
  gz) find . -print | cpio -o -H newc 2>/dev/null | gzip >../$INITRAMFS.img
  ;;
  xz) find . -print | cpio -o -H newc 2>/dev/null | xz -T0 -f --extreme --check=crc32 >../$INITRAMFS.img
  ;;
  zst) find . -print | cpio -o -H newc 2>/dev/null | zstd -6 >../$INITRAMFS.img  # wiak - should investigate alternative compression factors
  ;;
esac

echo $INITRAMFS.img

cd ..
rm -Rf $INITRAMFS
### END extract from Thomas M initramfs_create (with very minor mods/additions)

# Leaving old initrd.img if exists in case wanted; if so you need to manually rename new one prior to use
[ -f initrd.img ] && mv $INITRAMFS.img initrd.img

# clean up temporary symlink to firstrib_rootfs kernel modules
[ -L "/lib/modules/$KERNEL" ] && rm -f "/lib/modules/$KERNEL"

exit 0
