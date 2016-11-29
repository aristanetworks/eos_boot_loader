#!/bin/bash
################################################################################
# This installer does the following
# 1) Creates 3 partitions (boot, bootimage, persist)
# 2) Installs grub2 to part 1 (boot)
# 3) Formats part 2 (bootimage/bootimage) with EXT4
# 4) Formats part 3 (persist/[/mnt/flash]) with EXT4
################################################################################

MIN_DISK_SIZE=10G
BOOT_PART=500M
BOOTIMAGE_PART=4G

################################################################################

set -e

export PATH=$PWD:$PATH
. autoinit.settings || exit 2
. libbashbyte || exit 2

################################################################################

# Remove /dev if present in disk
disk=$(echo $1 | sed 's/\///g' | sed 's/dev//g')
[[ $disk ]] || { echo "Usage: disk" 1>&2; exit 2; }

devdisk="/dev/${disk}"
[ -b $devdisk ] || { echo "Device $devdisk is not a block device" 1>&2; exit 3; }

sectors=$(cat /sys/block/${disk}/size)
physical_block_size=$(cat /sys/block/${disk}/queue/physical_block_size)
size=$(expr $sectors \* $physical_block_size)

### Validate disk size ###
disk_size="$(expr $sectors \* $physical_block_size)B"
min_size=$(to_bytes_nosign $MIN_DISK_SIZE)

echo "Disk size is $(to_logical_size_unit $disk_size)" 1>&2

[ $size -lt $min_size ] && {
   echo "Less then minimal required size of $(to_logical_size_unit $MIN_DISK_SIZE)" 1>&2
   exit 1
}

echo "Meets minimal required size of $(to_logical_size_unit $MIN_DISK_SIZE)" 1>&2

boot_size=$(to_megabytes_nosign $BOOT_PART)
bootimage_size=$(to_megabytes_nosign $BOOTIMAGE_PART)
bootimage_start=$(expr $boot_size + 1)
persist_start=$(expr $bootimage_start + $bootimage_size + 1)

grubfile=/tmp/grub.cfg

cat > install.sh <<EOF
#!/bin/bash
set -e

wipefs -f -a $devdisk
parted -s $devdisk mklabel msdos
  
parted -a optimal $devdisk mkpart primary 0% ${boot_size}M
parted -a optimal $devdisk mkpart primary ${bootimage_start}M ${bootimage_size}M
parted -a optimal $devdisk mkpart primary ${persist_start}M 100%
parted -s $devdisk toggle 1 boot

mkfs.ext4 -F ${devdisk}1
mkfs.ext4 -L $BOOTIMAGE_LABEL -F ${devdisk}2
mkfs.ext4 -L $PERSIST_LABEL ${devdisk}3

mkdir -p /boot

mount ${devdisk}1 /boot

grub2-install $devdisk

cp -r isolinux /boot

### Generate kernel boot arg
# Get any args from the kernel boot command that match console* and
# append them to the new kernel boot string

for arg in $(cat /proc/cmdline | tr ";" "\n"); do
   [[ "$arg" =~ console.* ]] && boot_opts+=" $arg "
done

echo "set default='boot'" > /boot/grub2/grub.cfg
echo "set timeout=3" >> /boot/grub2/grub.cfg
echo "menuentry 'boot' {" >> /boot/grub2/grub.cfg
echo "   set root=(hd0,msdos1)" >> /boot/grub2/grub.cfg
echo "   linux /isolinux/vmlinuz $boot_opts" >> /boot/grub2/grub.cfg
echo "   initrd /isolinux/initrd" >> /boot/grub2/grub.cfg
echo "}" >> /boot/grub2/grub.cfg

echo "Rebooting in 2 seconds"
sleep 2
/shutdown
EOF

echo "Please review the file install.sh and then execute it"

chmod +x install.sh

################################################################################
