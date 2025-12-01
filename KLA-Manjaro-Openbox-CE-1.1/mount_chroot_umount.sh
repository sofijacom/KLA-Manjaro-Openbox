#!/bin/sh
# mount_chroot_umount.sh
# Creation Date: 23May2019 Revision Date: 28Aug2023
# wiak 23 May 2019+; Licence MIT (aka X11 license)

# This script is provided purely as a convenience so you don't have to
# keep entering the following commands to chroot into firstrib_rootfs

progname="mount_chroot_umount.sh"; version="3.0.1"; revision="-rc4"

case "$1" in
	'') chroot_dir="firstrib_rootfs";;
	'--version') printf "$progname ${version}${revision}\n"; exit 0;;
	'-h'|'--help'|'-?') printf "Run this script from location of the directory you want to chroot into with command:
  $progname [chroot_dir]
  If no arg is supplied directory firstrib_rootfs will be assumed.
  For example: ./$progname 08firstrib_rootfs\n";exit 0;;
	-*) printf "option $1 not available\n";exit 0;;
	*) chroot_dir="$1";;
esac
chroot_dir=`basename "$chroot_dir"`
echo chroot directory is $chroot_dir
# mount a directory to share between host system and firstrib_rootfs system.
# WARNING! I've commented this out because it is dangerous... For example
#   using bind mount to /mnt/home I accidentally zapped my main OS because I used rm -rf whilst mounted...
# Example (may need modified, or commented out, depending on set up of your system and
# what dir you want to share):
# mkdir -p "${chroot_dir}"/mnt/home
# mount --bind /mnt/home "${chroot_dir}"/mnt/home
# bind mount host virtual filesystes required for chroot into firstrib_rootfs to work on host system
if [ -d "$chroot_dir" ]; then
 mkdir -p "${chroot_dir}"/run/udev
else
 echo "No $chroot_dir directory found so exiting!"
 exit 1
fi
[ -e "${chroot_dir}"/etc/resolv.conf -o -L "${chroot_dir}"/etc/resolv.conf ] && mv "${chroot_dir}"/etc/resolv.conf "${chroot_dir}"/etc/resolv.confORIG
rm -f "${chroot_dir}"/etc/resolv.conf
cp -aL /etc/resolv.conf "${chroot_dir}"/etc/resolv.conf  # changing etc/resolv.conf causes problems sometimes. For example, systemd distros want to auto-create resolv.conf as a symlink and cannot copy over dangling symlink
mount --bind /proc "${chroot_dir}"/proc && mount --bind /sys "${chroot_dir}"/sys && mount --bind /dev "${chroot_dir}"/dev && mount -t devpts devpts "${chroot_dir}"/dev/pts && mount --bind /tmp "${chroot_dir}"/tmp && mount --bind /run/udev "${chroot_dir}"/run/udev

# chroot into firstrib rootfs and execute a /bin/sh process from that root filesystem
chroot "${chroot_dir}" sh
rm -f "${chroot_dir}"/etc/resolv.conf
[ -e "${chroot_dir}"/etc/resolv.confORIG -o -L "${chroot_dir}"/etc/resolv.confORIG ] && mv "${chroot_dir}"/etc/resolv.confORIG "${chroot_dir}"/etc/resolv.conf  # put back resolv.conf to its original form
# When finished working in the above chroot you need to enter exit in the chroot shell
# and then clean up the above mounts.
# As a convenience you can run the provided umount_chroot.sh script that contains
# the commands to clean up (umount) the bind mounts that were used.

# Clean up the bind mounts that were used for the chroot:
umount -l "${chroot_dir}"/proc && umount -l "${chroot_dir}"/sys && umount -l "${chroot_dir}"/dev/pts && umount -l "${chroot_dir}"/dev && umount -l "${chroot_dir}"/tmp && umount -l "${chroot_dir}"/run/udev
