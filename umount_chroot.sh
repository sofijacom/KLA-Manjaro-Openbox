#!/bin/sh
# umount_chroot.sh
# Creation Date: 23May2019 Revision Date: 23Sep2021
# wiak 23 May 2019+; Licence MIT (aka X11 license)

# This script is provided purely as a convenience so you don't have to
# keep entering the following commands to cleanup the firstrib_rootfs chroot:

progname="umount_chroot.sh"; version="3.0.0"; revision="-rc1"

case "$1" in
	'') chroot_dir="firstrib_rootfs";exit;;
	'--version') printf "$progname ${version}${revision}\n"; exit 0;;
	'-h'|'--help'|'-?') printf "Run this script from location of the chroot directory with command:
  $progname [chroot_dir]
  If no arg is supplied directory firstrib_rootfs will be assumed.
  For example: ./$progname 08firstrib_rootfs\n";exit 0;;
	-*) printf "option $1 not available\n";exit 0;;
	*) chroot_dir="$1";;
esac
chroot_dir=`basename "$chroot_dir"`

# bind mount host virtual filesystes required for chroot into firstrib_rootfs to work on host system
if [ -d "$chroot_dir" ]; then
 echo "Cleaning up mounts to chroot directory $chroot_dir"
else
 echo "No $chroot_dir directory found so exiting!"
 exit 1
fi
# Clean up the bind mounts that were used for the chroot:
umount -l "${chroot_dir}"/proc && umount -l "${chroot_dir}"/sys && umount -l "${chroot_dir}"/dev/pts && umount -l "${chroot_dir}"/dev && umount -l "${chroot_dir}"/tmp && umount -l "${chroot_dir}"/run/udev

# umount directory shared between host system and "${chroot_dir}" system.
# Example (may need modified, or commented out, depending on set up of your system and
# what dir you shared):
# Commented out since not used for now: see WARNING note in mount_chroot.sh
# umount "${chroot_dir}"/mnt/home
