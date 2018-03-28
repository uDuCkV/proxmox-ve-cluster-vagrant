#!/bin/bash
set -eux

sed -E -i 's/^GRUB_CMDLINE_LINUX="(.*)"/GRUB_CMDLINE_LINUX="\1 net.ifnames=0"/' /etc/default/grub
update-grub
