#!/bin/bash
set -eux

ip=$1

# configure apt for non-interactive mode.
export DEBIAN_FRONTEND=noninteractive

# update the package cache.
apt-get update

# install tcpdump to locally being able to capture network traffic.
apt-get install -y tcpdump

# install dumpcap to remotely being able to capture network traffic using wireshark.
groupadd --system wireshark
usermod -a -G wireshark vagrant
cat >/usr/local/bin/dumpcap <<'EOF'
#!/bin/sh
# NB -P is to force pcap format (default is pcapng).
# NB if you don't do that, wireshark will fail with:
#       Capturing from a pipe doesn't support pcapng format.
exec /usr/bin/dumpcap -P "$@"
EOF
chmod +x /usr/local/bin/dumpcap
echo 'wireshark-common wireshark-common/install-setuid boolean true' | debconf-set-selections
apt-get install -y --no-install-recommends wireshark-common

# install vim.
apt-get install -y --no-install-recommends vim
cat >/etc/vim/vimrc.local <<'EOF'
syntax on
set background=dark
set esckeys
set ruler
set laststatus=2
set nobackup
EOF

# configure the shell.
cat >/etc/profile.d/login.sh <<'EOF'
[[ "$-" != *i* ]] && return
export EDITOR=vim
export PAGER=less
alias l='ls -lF --color'
alias ll='l -a'
alias h='history 25'
alias j='jobs -l'
EOF

cat >/etc/inputrc <<'EOF'
set input-meta on
set output-meta on
set show-all-if-ambiguous on
set completion-ignore-case on
"\e[A": history-search-backward
"\e[B": history-search-forward
"\eOD": backward-word
"\eOC": forward-word
EOF


#
# setup NAT.
# see https://help.ubuntu.com/community/IptablesHowTo

apt-get install -y iptables

# enable IPv4 forwarding.
sysctl net.ipv4.ip_forward=1
sed -i -E 's,^\s*#?\s*(net.ipv4.ip_forward=).+,\11,g' /etc/sysctl.conf

# NAT through eth0.
iptables -t nat -A POSTROUTING -s "$ip/24" ! -d "$ip/24" -o enp0s3 -j MASQUERADE

# load iptables rules on boot.
iptables-save >/etc/iptables-rules-v4.conf
cat >/etc/network/if-pre-up.d/iptables-restore <<'EOF'
#!/bin/sh
iptables-restore </etc/iptables-rules-v4.conf
EOF
chmod +x /etc/network/if-pre-up.d/iptables-restore


#
# provision the DNS/DHCP server.
# see http://www.thekelleys.org.uk/dnsmasq/docs/setup.html
# see http://www.thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html

apt-get install -y dnsutils dnsmasq
cat >/etc/dnsmasq.d/local.conf <<EOF
interface=eth1
dhcp-range=10.1.0.2,10.1.0.200,1m
host-record=example.com,$ip
server=8.8.8.8
EOF
systemctl restart dnsmasq


#
# provision the NFS server.
# see exports(5).

apt-get install -y nfs-kernel-server
install -d -o nobody -g nogroup -m 700 /srv/nfs/iso-templates
cat >>/etc/exports <<EOF
/srv/nfs/iso-templates $ip/24(fsid=0,rw,no_subtree_check)
EOF
systemctl restart nfs-kernel-server
