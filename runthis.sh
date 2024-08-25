#!/bin/bash
umount /mnt/barchinstall/boot
umount /mnt/barchinstall/ -R 
swapoff -a
mkdir /mnt/barchinstall/boot/efi -p
B_DIR="/mnt/barchinstall/"
ERROR_CRASH="if [[ $? -ne 0 ]] ; then
    echo oh no somthing went wrong!
    exit 1
fi"
clear
echo "which disk would you like to install too?"
lsblk | grep disk
read -r DISK
cfdisk /dev/"$DISK"
$ERROR_CRASH
clear 

echo "ext4, xfs or jfs? >  "
read -r FILE_SYS
clear

# shellcheck disable=SC2010
echo "which device is the root partition $(ls /dev/ | grep "$DISK")"
read -r ROOT_P
wipefs -a /dev/"$ROOT_P"
mkfs."$FILE_SYS" "$ROOT_P"
mount /dev/"$ROOT_P" $B_DIR
$ERROR_CRASH
clear

# shellcheck disable=SC2010
echo "which of these is your boot partition? $(ls /dev/ | grep "$DISK")"
read -r BOOT_P
wipefs -a /dev/"$BOOT_P"
mkfs.fat -F 32 /dev/"$BOOT_P"
 mount /dev/"$BOOT_P" "$B_DIR"boot
clear

echo "is there anyswap? if so choose your swap part! (leave blank if none) $(lsblk | grep disk)" 
read -r SWAP_P
if [ -n "$SWAP_P" ]; then
    wipefs -a /dev/$SWAP_P
    swapon /dev/"$SWAP_P"
fi
clear

echo "which kernel would you like to use? (linux, linux-zen, linux-lts, linux-hardened)"
read -r KERNEL
echo "what other packages would you like to use? eg: de/wm (base linux-firmware nano vim vi kitty rust git wget rust gcc and llvm all included)"
read -r OTH_P
pacstrap -K "$B_DIR" base linux-firmware nano vim vi kitty rust git wget rust gcc llvm sudo which grub efibootmgr reflector "$KERNEL" "$OTH_P"
genfstab -U "$B_DIR" >> /mnt/barchinstall/etc/fstab

# shellcheck disable=SC1072
# shellcheck disable=SC1073
cat << EOF | arch-chroot $B_DIR
    echo "--save /etc/pacman.d/mirrorlist
    --country United Kingdom
    --protocol https
    --latest 5">> /etc/xdg/reflector/reflector.conf
    systemctl enable reflector.service
    clear

    echo "Which Region are you in? $(ls /usr/share/zoneinfo)"
    read REGION
    clear
    echo "Which City are you in/closest too?"
    $(ls /usr/share/zoneinfo/"$REGION")
    read CITY
    clear
    ln -sf /usr/share/zoneinfo/"$REGION"/"$CITY"
    hwclock --systohc
    clear
    echo 'list all your locales now :)'
    read LOCALES
    echo "$LOCALES" >> /etc/locale.gen
    locale-gen
    clear
    echo "type your password now!"
    passwd
    echo "do you want too add a user?"
    read USER_N
    if [ -n $USER_N ]; then
    useradd -mG wheel,video,input,audio $USER_N
    echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
    passwd $USER_N
    su $USER_N
    cd ~
    clear
    git clone https://github.com/vidfurlan/dotfiles
    cd dotfiles
    ./install.sh
    cd .. && rm -drf dotfiles
    chsh -s $(which zsh)
    git clone https://aur.archlinux.org/paru-bin.git
    cd paru-bin
    makepkg
    rm *debug*
    sudo pacman -U --noconfirm paru-bin-*.*
    cd .. && rm -drf paru-bin
    exit
    fi
    grub-install --target=x86_64-efi --efi-directory=/boot/efi
    grub-mkconfig -o /boot/grub/grub.cfg
EOF
$ERROR_CRASH
clear
echo "do you wanna chroot in? y/n"
read CHROOT_Y_N
if [[ "$CHROOT_Y_N" == "y" ]]; then 
    arch-chroot $B_DIR
    $ERROR_CRASH
fi
echo "bye bye :)"
