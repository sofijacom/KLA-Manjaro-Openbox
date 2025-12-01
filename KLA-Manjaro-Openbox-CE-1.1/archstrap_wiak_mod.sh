#!/bin/bash
# Create archlinux rootfs without archlinux
set -e
# Parsing argumenst
rootfs=$(realpath "$1")
shift
while getopts -- ':r:g:i:p:' OPTION; do
    case $OPTION in
    r)
      mirror="${OPTARG[@]}"
      ;;
    g)
      format="${OPTARG[@]}"
      ;;
    i)
      ignore="${OPTARG[@]}"
      ;;
    p)
      pacman_conf="$(realpath "${OPTARG[@]}")"
      ;;
    *)
      echo "usage: archstarp (rootfs) [options]"
      echo "    -i : disable repo section"
      echo "    -r : used repo url"
      echo "    -g : repo index archive format"
      echo "    -p : use custom pacman.conf file"
      exit 1
    esac
done
[[ $UID -ne 0 ]] && echo "You must be root" && exit 31
# Define and check variables
[[ "$rootfs" == "" ]] && echo "Rootfs directory is invalid" && exit 1
[[ "$arch" == "" ]] && arch=$(uname -m)
[[ "$mirror" == "" ]] && mirror="https://mirrors.gigenet.com/manjaro/stable/\$repo/\$arch"
[[ "$format" == "" ]] && format="tar.gz"
repo=$(echo "https://mirrors.gigenet.com/manjaro/stable/\$repo/\$arch" | sed "s/\$repo/core/g;s/\$arch/$arch/g")
packages=(filesystem pacman base brotli coreutils bash ncurses libarchive openssl zstd curl gpgme
          expat xz lz4 bzip2 archlinux-keyring zlib libssh2 libassuan idn2 libpsl krb5
          libnghttp2 libnghttp3 e2fsprogs keyutils pacman-mirrorlist gnupg sqlite libgcrypt gawk
          file p11-kit findutils libp11-kit libtasn1 libffi mpfr gmp grep pcre libcap libxml2 icu audit libcap-ng attr pcre2 libxcrypt pam libseccomp
gcc-libs gettext glibc gzip iproute2 iputils licenses pciutils procps-ng psmisc shadow systemd systemd-sysvcompat tar util-linux) #wiak added
# Creating base directories
mkdir -p "$rootfs" && cd "$rootfs"
mkdir -p "$rootfs"/tmp/core-db
mkdir -p "$rootfs"/var/cache/pacman/pkg
mkdir -p "$rootfs"/etc/pacman.d/
# Define functions
fetch(){
    set +e
    url="$1"
    dest="$2"
    echo "D: $(basename $url)"
    if [[ ! -f "$dest" ]] ; then
        wget -c "$url" -O "$dest"
    fi
    set -e
}
deplist=()
getdep(){
    for pkg in $@ ; do
        name=$(echo $pkg | sed "s/>.*//g;s/<.*//g;s/>=*//g")
        desc=$(ls "$rootfs"/tmp/core-db/"$name"-[0-9]*/desc 2>/dev/null | tail -n 1)
        [[ ! -f "$desc" ]] && continue
        deps=()
        enable="false"
        echo $name
        cat $desc | while read line ; do
            line=$(echo $line | sed "s/>.*//g;s/<.*//g;s/>=*//g")
            if [[ "$line" == "%DEPENDS%" ]] ; then
                enable="true"
            elif [[ "$line" == "" ]] ; then
                enable="false"
            elif [[ "$enable" == "true" ]] ; then
                if ! echo ${deplist[@]} | grep $line &>/dev/null ; then
                    deplist+=($line)
                    getdep $line
                fi
            fi
        done
    done
}
get_url(){
    for pkg in $@ ; do
        name=$(echo $pkg | sed "s/>.*//g;s/<.*//g;s/>=*//g")
        desc=$(ls "$rootfs"/tmp/core-db/"$name"-[0-9]*/desc 2>/dev/null | tail -n 1)
        [[ ! -f "$desc" ]] && continue
        cat $desc | while read line ; do
            if [[ "$line" == "%FILENAME%" ]] ; then
                read filename
                echo $filename
            fi
        done
    done
}

# Download core database
cd "$rootfs"/tmp/core-db
fetch "$repo/core.db.$format" core.db.$format || true
tar -xf core.db.$format
cd "$rootfs"
# Install standalone pacman in rootfs
getdep ${packages[@]} | sort | uniq | while read pkg ; do
    echo $pkg
    name=$(get_url $pkg)
    fetch "$repo"/$name "$rootfs"/var/cache/pacman/pkg/$name
    tar -xf "$rootfs"/var/cache/pacman/pkg/$name || true
    rm -f "$rootfs"/.INSTALL "$rootfs"/.MTREE "$rootfs"/.BUILDINFO || true
done
# mirror list write
touch "$rootfs"/etc/pacman.d/mirrorlist
if ! grep "archstrap" "$rootfs"/etc/pacman.d/mirrorlist ; then
    echo "" >> "$rootfs"/etc/pacman.d/mirrorlist
    echo "# Added by archstrap" >> "$rootfs"/etc/pacman.d/mirrorlist
    echo "Server = $mirror" >> "$rootfs"/etc/pacman.d/mirrorlist
fi
# install custom pacman.conf if available
if [[ -f "${pacman_conf}" ]] ; then
    cat "${pacman_conf}" > "$rootfs"/etc/pacman.conf
fi
# pacman.conf configurations
sed -i 's/^CheckSpace/#CheckSpace/g' "$rootfs"/etc/pacman.conf
sed -i 's/^#ParallelDownloads/ParallelDownloads/g' "$rootfs"/etc/pacman.conf
sed -i 's/^DownloadUser/#DownloadUser/g' "$rootfs"/etc/pacman.conf
sed -i "s/^[[:space:]]*\(CheckSpace\)/# \1/" "$rootfs"/etc/pacman.conf
sed -i "s/^[[:space:]]*SigLevel[[:space:]]*=.*$/SigLevel = Never/" "$rootfs"/etc/pacman.conf
for i in $ignore ; do
    sed -i -e '/^\['$i'\]/ { N; N; d; }' "$rootfs"/etc/pacman.conf
done
# Fix file conflict error
rm -rf "$rootfs/var/spool/mail"
# Dns configurations
cat /etc/resolv.conf > "$rootfs"/etc/resolv.conf
# Bind system
for i in dev sys proc run ; do
    mount --bind /$i "$rootfs"/$i
done
# Install base
busybox chroot "$rootfs" update-ca-trust
busybox chroot "$rootfs" pacman -Sy || true
mkdir -p "$rootfs"/newroot/var/lib/pacman/
mkdir -p "$rootfs"/newroot/var/cache/pacman/
cp -prf "$rootfs"/var/cache/pacman/* "$rootfs"/newroot/var/cache/pacman/
busybox chroot "$rootfs" pacman -Syy base bash pacman --noconfirm --overwrite \* --root=/newroot
# Umount all
for i in dev sys proc run ; do
    while umount -lf -R "$rootfs"/$i 2>/dev/null ; do true ; done
done
# replace rootfs with existing
mkdir -p "$rootfs/garbage"
mv "$rootfs"/* "$rootfs/garbage" 2>/dev/null || true
mv "$rootfs/garbage/newroot/"* "$rootfs/"
rm -rf "$rootfs/garbage"

# Dns configurations
cat /etc/resolv.conf > "$rootfs"/etc/resolv.conf
touch "$rootfs"/etc/pacman.d/mirrorlist

if ! grep "archstrap" "$rootfs"/etc/pacman.d/mirrorlist ; then
    echo "" >> "$rootfs"/etc/pacman.d/mirrorlist
    echo "# Added by archstrap" >> "$rootfs"/etc/pacman.d/mirrorlist
    echo "Server = $mirror" >> "$rootfs"/etc/pacman.d/mirrorlist
fi

busybox chroot "$rootfs" pacman-key --init
busybox chroot "$rootfs" pacman -Syyu --noconfirm
# pacman.conf configurations
# pacman.conf configurations
sed -i 's/^CheckSpace/#CheckSpace/g' "$rootfs"/etc/pacman.conf
sed -i 's/^#ParallelDownloads/ParallelDownloads/g' "$rootfs"/etc/pacman.conf
sed -i 's/^#Color/Color/g' "$rootfs"/etc/pacman.conf
sed -i 's/^#DownloadUser/DownloadUser/g' "$rootfs"/etc/pacman.conf
sed -i "s/^[[:space:]]*\(CheckSpace\)/# \1/" "$rootfs"/etc/pacman.conf
sed -i "s/^[[:space:]]*SigLevel[[:space:]]*=.*$/SigLevel = Never/" "$rootfs"/etc/pacman.conf
