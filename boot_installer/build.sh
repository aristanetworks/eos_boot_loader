#!/bin/bash
################################################################################

set -e

[[ $KVER ]] || { echo "Required var KVER not set!"; exit 2; }
[[ $LABEL ]] || { echo "Required var LABEL not set!"; exit 2; }

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
dinstall+=" md5sum zip unzip less touch sync expr "
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

####################################################################################################

syslinux="/usr/share/syslinux"

mkdir -p $builddir/isolinux
install -m 0644 $syslinux/isolinux.bin $builddir/isolinux
install -m 0644 $syslinux/ldlinux.c32 $builddir/isolinux
install -m 0644 $syslinux/libcom32.c32 $builddir/isolinux
install -m 0644 $syslinux/libutil.c32 $builddir/isolinux
install -m 0644 $syslinux/vesamenu.c32 $builddir/isolinux

install -m 0644 /boot/memtest86+-5.01 $builddir/isolinux/memtest

install -m 0755 /usr/lib/modules/${KVER}/vmlinuz $builddir/isolinux

install -m 0644 $builddir/initrd $builddir/isolinux

cp -r /usr/lib/grub $builddir

cat << EOF > $builddir/isolinux/isolinux.cfg
default vesamenu.c32
timeout 100
menu background

menu clear
menu title Boot Installer
menu vshift 8
menu rows 18
menu margin 8
menu helpmsgrow 15
menu tabmsgrow 13
menu tabmsg Press Tab for full configuration options on menu items.
menu separator
menu separator

label vga
  menu label ^VGA install
  kernel vmlinuz
  append initrd=initrd
label serial0
  menu label ^Serial Console 0 install
  kernel vmlinuz
  append initrd=initrd console=ttyS0,115200n8
label serial0
  menu label ^Serial Console 1 install
  kernel vmlinuz
  append initrd=initrd console=ttyS1,115200n8
menu separator
label memtest
  menu label ^Memory test.
  text help
    Run system memory test
  endtext
  kernel memtest
menu separator
label returntomain
  menu label Return to ^main menu.
  menu exit
menu end
EOF

rm -rf dist; mkdir dist

xorriso -as mkisofs \
        -V $LABEL \
        -o dist/${LABEL}.iso \
        -isohybrid-mbr /usr/share/syslinux/isohdpfx.bin \
        -c isolinux/boot.cat \
        -b isolinux/isolinux.bin \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        $builddir

echo "Build $(pwd) complete"

################################################################################
