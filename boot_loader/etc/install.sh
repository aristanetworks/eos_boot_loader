#!/bin/bash
################################################################################
# This installer does the following
# 1) Creates 3 partitions (boot, bootimage, persist)
# 2) Installs grub2 to part 1 (boot)
# 3) Formats part 2 (bootimage/bootimage) with EXT4
# 4) Formats part 3 (persist/[/mnt/flash]) with EXT4
################################################################################

export PATH=$PWD:$PATH
. autoinit.settings || exit 2

#### Main ######################################################################

function main() {
   disk=$1

   [[ $disk ]] ||  { echo "Usage:$0 disk (/dev/sda)"; return 2; }
   [ -b $disk ] || { echo "Disk is not a valid block device"; return 2; }

   cd
   _installer $disk || { echo "Installer failed"; return 3; }

   echo "successfully installed! Please remove install media and reboot"
}

#### Installer #################################################################

function _installer() {
   disk=$1

   trap cleanup EXIT > /dev/null 2>&1

   wipefs -f -a $disk || { echo "Disk wipe failed"; return 3; }
   parted -s $disk mklabel msdos || { echo "Disk label failed"; return 3; }
   parted -s $disk mkpart primary 0% 1% ||
      { echo "Disk partition failed"; return 3; }
   parted -s $disk mkpart primary 2% 40% ||
      { echo "Disk partition failed"; return 3; }
   parted -s $disk mkpart primary 41% 100% ||
      { echo "Disk partition failed"; return 3; }
   parted -s $disk toggle 1 boot || return 3

   mkfs.ext4 -F ${disk}1 || return 3
   mkfs.ext4 -L $BOOTIMAGE_LABEL -F ${disk}2 || return 3
   mkfs.ext4 -L $PERSIST_LABEL ${disk}3 || return 3

   mkdir -p /boot || return 3

   mount ${disk}1 /boot || { echo "Mount failed"; return 3; }

   grub2-install $disk || { echo "Grub install failed"; return 3; }

   cp -r isolinux /boot || { echo "Isolinux install failed"; return 3; }

   ### Generate kernel boot arg
   # Get any args from the kernel boot command that match console* and
   # append them to the new kernel boot string

   [ -f /proc/cmdline ] || { echo "/proc/cmdline not found"; return 3; }
   for arg in $(cat /proc/cmdline | tr ";" "\n"); do
      [[ "$arg" =~ console.* ]] && boot_opts+=" $arg "
   done

   echo "Boot Options->${boot_opts}"

   file=/tmp/grub.cfg
   echo "set default='boot'" > $file
   echo "set timeout=3" >> $file
   echo "menuentry 'boot' {" >> $file
   echo "   set root=(hd0,msdos1)" >> $file
   echo "   linux /isolinux/vmlinuz $boot_opts" >> $file
   echo "   initrd /isolinux/initrd" >> $file
   echo "}" >> $file
   cat $file > /boot/grub2/grub.cfg ||
      { echo "Grub.cfg install failed"; return 3; }
}

function cleanup {
   exit_code=$?
   [ $exit_code -eq 0 ] && {
      echo "Install successful, review file /boot/grub2/grub.cfg"
      sync; sync
   } || {
      echo "Install failed!"
   }
}

################################################################################
main $@
