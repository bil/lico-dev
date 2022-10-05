#! /bin/bash

set -ev

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
wget https://git.kernel.org/pub/scm/linux/kernel/git/rt/linux-stable-rt.git/snapshot/linux-stable-rt-5.4.209-rt77.tar.gz
#wget -N https://kernel.org/pub/linux/kernel/v5.x/linux-5.4.209.tar.gz
#
# to check signature
# sudo apt-get install gnupg2
# gpg2 --locate-keys torvalds@kernel.org gregkh@kernel.org
# gpg2 --generate-key # Enter name and email; create password
# wget -N https://kernel.org/pub/linux/kernel/v5.x/linux-5.4.209.tar.sign
# gunzip linux-5.4.209.tar.gz
# gpg2 --verify linux-5.4.209.tar.sign linux-5.4.209.tar


# reset kernel folder and extract linux source
rm -rf $KERNEL_DIR
mkdir -p $KERNEL_DIR
cd $KERNEL_DIR
tar -zxvf $TMP_DIR/linux-stable-rt-5.4.209-rt77.tar.gz

# copy kernel .config file from git
cp $INSTALL_DIR/.config $KERNEL_DIR/linux-stable-rt-5.4.209-rt77/.config

# build kernel
cd $KERNEL_DIR/linux-stable-rt-5.4.209-rt77
# TODO revisit
# https://askubuntu.com/questions/1329538/compiling-the-kernel-5-11-11
scripts/config --disable SYSTEM_TRUSTED_KEYS
make-kpkg clean
CONCURRENCY_LEVEL=$NUM_CPUS fakeroot make-kpkg --initrd --append-to-version=-licorice binary

# install kernel
sudo dpkg --force-confdef --force-confnew -i $KERNEL_DIR/linux-image-5.4.209-licorice-rt77_5.4.209-licorice-rt77-10.00.Custom_amd64.deb
sudo dpkg --force-confdef --force-confnew -i $KERNEL_DIR/linux-headers-5.4.209-licorice-rt77_5.4.209-licorice-rt77-10.00.Custom_amd64.deb

# notify reboot when done
printf "\n\n%s\n" "Kernel installation complete. Please reboot the system."
#sudo reboot
