#! /bin/bash

# Kernel patch script for Ubuntu xenial-lts server (16.04)

# This is to be executed from the LiCoRICE repository directory

# set some variables
INSTALL_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
KERNEL_DIR=`pwd`/../rt_kernel
TMP_DIR=/tmp

NUM_CPUS=`grep processor /proc/cpuinfo|wc -l`

# update to most recent version of packages, install essentials, do some cleanup
sudo apt-get update
sudo apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" upgrade
sudo apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" install libncurses5-dev build-essential libssl-dev kernel-package dwarves libelf-dev flex
sudo apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" autoremove

# download kernel and rt-patch if not exists
cd $TMP_DIR
wget -N https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/linux-5.4.209.tar.gz
wget -N https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/5.4/patch-5.4.209-rt77.patch.gz

# reset kernel folder and extract linux source
rm -rf $KERNEL_DIR
mkdir -p $KERNEL_DIR
cd $KERNEL_DIR
tar -zxvf $TMP_DIR/linux-5.4.209.tar.gz

# copy kernel .config file from git
cp $INSTALL_DIR/.config $KERNEL_DIR/linux-5.4.209/.config

# patch kernel with realtime patch
cd $KERNEL_DIR/linux-5.4.209
# TODO could use xz to decrease memory needed? but would be slower
# zcat $TMP_DIR/patch-5.4.209-rt77.patch.gz | patch -p1

# build kernel
make-kpkg clean
CONCURRENCY_LEVEL=$NUM_CPUS fakeroot make-kpkg --initrd --append-to-version=-licorice binary

# install kernel
sudo dpkg --force-confdef --force-confnew -i $KERNEL_DIR/linux-image-5.4.209-licorice-rt77_5.4.209-licorice-rt77-10.00.Custom_amd64.deb
sudo dpkg --force-confdef --force-confnew -i $KERNEL_DIR/linux-headers-5.4.209-licorice-rt19_5.4.209-licorice-rt77-10.00.Custom_amd64.deb

# notify reboot when done
printf "\n\n%s\n" "Kernel installation complete. Please reboot the system."
#sudo reboot
