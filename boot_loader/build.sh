#!/bin/bash
################################################################################

set -e

[[ $KVER ]] || { echo "Required var KVER not set!"; exit 2; }

################################################################################

function cleanup {
   exit_code=$?
   [ $exit_code -eq 0 ] || echo "Build $(pwd) Failed"
   echo "Cleaning up"
   [[ $builddir ]] && [ -d $builddir ] && rm -rf $builddir
}

trap cleanup EXIT

builddir=$(mktemp -d /tmp/isobuild.XXXXXX)
echo "build dir is $builddir"

modules+=" base "

# modules+=" dmsquash-live pollcdrom "
# modules+=" dmsquash-live "
modules+=" network "

# drivers+=" ieee1394 ide-cd "
drivers+=" sr_mod sd_mod cdrom =ata sym53c8xx aic7xxx ehci_hcd "
drivers+=" uhci_hcd ohci_hcd usb_storage usbhid uas firewire-sbp2 "
drivers+=" sbp2 ohci1394 mmc_block sdhci sdhci-pci pata_pcmcia mptsas "
drivers+=" udf virtio_blk virtio_pci virtio_scsi virtio_net virtio_mmio "
drivers+=" virtio_balloon virtio-rng firewire-ohci "

filesystems=" isofs msdos xfs "

# Required
dinstall+=" fdisk parted mkfs.xfs wipefs df du rmdir chmod mountpoint "
dinstall+=" mksquashfs unsquashfs "
dinstall+=" xfs_admin mkfs.ext4 "
dinstall+=" md5sum zip unzip less install sync touch expr "
dinstall+=" grub2-install "

# Network support
dinstall+=" scp ssh ifconfig "

# dev tools
dinstall+=" vim "

./modified.dracut \
   --kver $KVER \
   --force \
   --no-hostonly \
   --add "$modules" \
   --add-drivers "$drivers" \
   --install "$dinstall" \
   --filesystems "$filesystems" $builddir/initrd > $builddir/dracut.log 2>&1 ||
      { cat $builddir/dracut.log; exit 3; }

syslinux="/usr/share/syslinux"

mkdir -p $builddir/bootloader/isolinux

install -m 0755 etc/configure.sh $builddir/bootloader
install -m 0644 etc/user_readme $builddir/README
install -m 0644 etc/autoinit.settings $builddir/bootloader
install -m 0644 etc/libbashbyte $builddir/bootloader

install -m 0644 $syslinux/isolinux.bin $builddir/bootloader/isolinux
install -m 0644 $syslinux/ldlinux.c32 $builddir/bootloader/isolinux
install -m 0644 $syslinux/libcom32.c32 $builddir/bootloader/isolinux
install -m 0644 $syslinux/libutil.c32 $builddir/bootloader/isolinux
install -m 0644 $syslinux/vesamenu.c32 $builddir/bootloader/isolinux

install -m 0644 $builddir/initrd $builddir/bootloader/isolinux
install -m 0755 /usr/lib/modules/${KVER}/vmlinuz $builddir/bootloader/isolinux

rm -rf dist; mkdir dist

cp -r $builddir/bootloader/* dist

echo "Build $(pwd) complete"

################################################################################
