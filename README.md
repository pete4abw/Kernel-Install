Kernel Install and Remove
=========================

Bash scripts for installing a new Kernel after building.
Both must be run as root.
Using **sudo** may cause failure in finding `depmod` command.
lilo or grub must be manually updated after.
Tested on **Slackware**.

kinstall.sh
-----------

This program will read from the kernel Makefile
* **KV** --> Kernel Version
* **PL** --> Patch Level
* **SL** --> Sub Level

This program will copy kernel files to /boot
* **.config** --> /boot/config-KV-PL-SL
* **System.map** --> /boot/System.map-KV-PL-SL
* **bzImage** --> /boot/vmlinuz-KV-PL-SL (currently only x86 kernel image)

It will link
* /usr/src/linux --> **/usr/src/linux-KV-PL-SL**
* and if necessary /usr/src/linux-KV-PL-SL --> **some remote directory**
  (if kernel source is linked to)

Then it will run mkinitrd using a configuration file **/etc/mkinitrd.conf**
* **initrd-KV-PL-SL.gz** is created in /boot

kremove.sh
----------

This program will not remove the current running Kernel (uname -r).

This program will remove
* **/boot/config-KV-PL-SL**
* **/boot/System.map-KV-PL-SL**
* **/boot/bzImage-KV-PL-SL**
* **/boot/initrd-KV-PL-SL**
* **/lib/modules/KV-PL-SL**
* **/usr/src/linux-KV-PL-SL**

Peter Hyman
pete@peterhyman.com

