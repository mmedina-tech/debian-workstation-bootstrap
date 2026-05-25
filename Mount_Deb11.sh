#!/bin/bash
# SYNOPSIS: Mount Debian 11 ISO's
#
# Mount_Deb11.sh
#
# Author: Marcus Medina,,,
# Date: Fri 07 Jan 2022 09:21:26 AM PST
# Last Update: 2022-03-22: 10:38
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This Program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABLILITY of FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You Should have recieved a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
#
#

iso=1
if [[ $UID != 0 ]]; then
    echo "You need to be root"
    exit
fi
mkdir -p /mnt/deb11_{1..22}
mount -a
read -rp "Full Path to ISO's: " fpath
fpath=${fpath%\/}
echo
echo "Mounting ISO's"
sleep 1
while true;
do
    if [[ ${iso} -eq 20 ]]; then
        break
    fi
    mount -v "${fpath}/debian-11.2.0-amd64-DVD-${iso}.iso" "/mnt/deb11_${iso}"
    ((iso += 1))
done
mount -v "${fpath}/debian-update-11.2.0-amd64-DVD-1.iso"  "/mnt/deb11_20"
mount -v "${fpath}/debian-update-11.2.0-amd64-DVD-2.iso" "/mnt/deb11_21"
mount -v "${fpath}/firmware-11.2.0-amd64-DVD-1.iso" "/mnt/deb11_22"
iso=1
echo
echo -n "Would you like to put these in the fstab [y/N]: "
read -r tab
if [[ ${tab:-N} =~ [yY] ]]; then
    while true;
    do
        if [[ ${iso} -eq 20 ]]; then
            break
        fi
        echo "${fpath}/debian-11.2.0-amd64-DVD-${iso}.iso" "/mnt/deb11_${iso}" "iso9660 auto,users,ro   0   0" >> /etc/fstab
        ((iso += 1))
    done
    echo "${fpath}/debian-update-11.2.0-amd64-DVD-1.iso" "/mnt/deb11_20" "iso9660 auto,users,ro     0   0" >> /etc/fstab
    echo "${fpath}/debian-update-11.2.0-amd64-DVD-2.iso" "/mnt/deb11_21" "iso9660 auto,users,ro     0   0" >> /etc/fstab
    echo "${fpath}/firmware-11.2.0-amd64-DVD-1.iso" "/mnt/deb11_22" "iso9660 auto,users,ro  0   0" >> /etc/fstab
fi
echo
echo -n "Would you like to add to apt sources.list [y/N]: "
read -r sources
if [[ ${sources:-N} =~ [yY] ]]; then
    isource=1
    while true;
    do
        if [[ ${isource} -eq 20 ]]; then
            break
        fi
        echo "deb [trusted=yes] file:/mnt/deb11_${isource} bullseye main contrib" >> /etc/apt/sources.list
        ((isource += 1))
    done
    isource=20
    while true;
    do
        if [[ ${isource} -eq 23 ]]; then
            break
        fi
        echo "deb [trusted=yes] file:/mnt/deb11_${isource} bullseye main contrib non-free" >> /etc/apt/sources.list
        ((isource += 1))
    done
fi
echo "Starting apt update"
sleep 1
apt update
