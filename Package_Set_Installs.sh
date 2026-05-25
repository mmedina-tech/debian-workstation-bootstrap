#!/bin/bash
# SYNOPSIS: Package Set Installs for Debian Based Distros
#
# Package_Set_Installs.sh
#
# Author: Marcus Medina,,,
# Date: Tue 28 Dec 2021 01:22:59 PM PST
# Last Update: 2025-02-24: 22:42
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

if [[ $EUID != 0 ]]; then
    echo "Please run as root"
    exit
fi
echo "Installing packages"
sleep 1
#install_packs=("python2.7*" "python3" "php" "vim*" "geany-*" "git" "meld" "libapache2-mod-php7.*" "libapache2-mod-python" "multitail" "aptitude" "thunderbird" "libdb-perl" "libmariadb-*" "apache2" "*screensaver*" "oxygencursors" "firmware-amd-graphics" "firmware-amd-sound" "firmware-linux-free" "firmware-linux-nonfree" "firmware-misc-nonfree" "firmware-realtek" "firmware-sof-signed" "phpmyadmin" "php-cli" "php-tidy")
install_packs=("meld" "libapache2-mod-python" "multitail" "aptitude" "thunderbird" "libdb-perl" "libmariadb-*" "apache2" "*screensaver*" "oxygencursors" "firmware-amd-graphics" "firmware-amd-sound" "firmware-linux-free" "firmware-linux-nonfree" "firmware-misc-nonfree" "firmware-realtek" "firmware-sof-signed")
for unpack in "${install_packs[@]}"
do
    nala install "${unpack}" -y
    #apt list "${unpack}"
done
echo
echo "Opening /var/www permisions"
chmod 777 "/var/www"
echo "Opening html permissions"
chmod 777 "/var/www/html"
echo
echo "Creating and opening permissions for cgi-bin"
mkdir "/var/www/cgi-bin"
chmod 777 "/var/www/cgi-bin"
echo
echo "Opening permissions for Apache Error and Access logs"
chmod 777 "/var/log/apache2"
chmod 777 "/var/log/apache2/access.log" "/var/log/apache2/error.log"
echo
echo "Enabling cgi-bin for apache"
a2enmod cgi
if systemctl "restart" "apache2" ; then
    echo "Apache restart successful"
else
    echo "Apache restart failed"
fi
source ./remove_vim_stuff.sh
echo
echo "To configure MySQL, read Chapter 65 of MySQL Notes for Professionals to set the root password"
echo -e "\nThank you for using InTech Package Installer"
