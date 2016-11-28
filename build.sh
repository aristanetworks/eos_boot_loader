#!/bin/bash
################################################################################

set -e
export LABEL="installer"

### Main #######################################################################

function main() {

   package_install
   # sub builders require KVER
   export KVER=$(get_kernel_version)

   pushd boot_loader; ./build.sh; popd
   rm -rf boot_installer/stuff
   cp -r boot_loader/dist boot_installer/stuff
   pushd boot_installer; ./build.sh; popd
   echo "Build successful"
}

### Package Install ############################################################

function package_install() {
   packs+=" vim kernel dracut dracut-live systemd-udev "
   packs+=" syslinux mkisofs squashfs-tools parted util-linux "
   packs+=" xfsprogs e2fsprogs openssh-clients net-tools xorriso "
   packs+=" kexec-tools less rsync "
   packs+=" grub2 grub2-tools memtest86+ "
   packs+=" lvm2 "

   dnf -y install $packs || { echo "Package install failed"; return 3; }
   
   install -m 0755 /usr/bin/vim /usr/bin/vi ||
      { echo "vi install failed"; return 3; }
}

### Kernel Version  ############################################################

function get_kernel_version() {
   # The number of kernels expected is 1
   kernel_count=$(/bin/ls -1 /usr/lib/modules | wc -l)

   [ $kernel_count -eq 1 ] || {
      fail_msg "Kernels in /usr/lib/modules is ${kernel_count}, expected 1; Fatal!"
      exit 3
   }
   kver=$(/bin/ls -1 /usr/lib/modules)
   echo $kver
}

################################################################################
main $@
