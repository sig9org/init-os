#!/bin/bash

function ubuntu_base() {
  # Set the timezone
  timedatectl set-timezone Asia/Tokyo

  # Configure NTP servers
  cat << EOF >> /etc/systemd/timesyncd.conf
  NTP=162.159.200.123 162.159.200.1
EOF

  # Update sshd
  sed -i -e "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/g" /etc/ssh/sshd_config
  sed -i -e "s/#ClientAliveInterval 0/ClientAliveInterval 60/g" /etc/ssh/sshd_config
  sed -i -e "s/#ClientAliveCountMax 3/ClientAliveCountMax 5/g" /etc/ssh/sshd_config

  # Disable SSH client warnings
  cat << EOF > /etc/ssh/ssh_config.d/99_lab.conf
KexAlgorithms +diffie-hellman-group1-sha1
Ciphers aes128-cbc,aes256-ctr
StrictHostKeyChecking no
UserKnownHostsFile=/dev/null
EOF

  # Enable /var/log/messages.
  cat << 'EOF' > /etc/rsyslog.d/50-default.conf
#  Default rules for rsyslog.
#
#   For more information see rsyslog.conf(5) and /etc/rsyslog.conf

#
# First some standard log files.  Log by facility.
#
auth,authpriv.*   /var/log/auth.log
*.*;auth,authpriv.none  -/var/log/syslog
#cron.*    /var/log/cron.log
#daemon.*   -/var/log/daemon.log
kern.*    -/var/log/kern.log
#lpr.*    -/var/log/lpr.log
mail.*    -/var/log/mail.log
#user.*    -/var/log/user.log

#
# Logging for the mail system.  Split it up so that
# it is easy to write scripts to parse these files.
#
#mail.info   -/var/log/mail.info
#mail.warn   -/var/log/mail.warn
mail.err   /var/log/mail.err

#
# Some "catch-all" log files.
#
#*.=debug;\
# auth,authpriv.none;\
# news.none;mail.none -/var/log/debug
*.=info;*.=notice;*.=warn;\
 auth,authpriv.none;\
 cron,daemon.none;\
 mail,news.none  -/var/log/messages

#
# Emergencies are sent to everybody logged in.
#
*.emerg    :omusrmsg:*

#
# I like to have messages displayed on the console, but only on a virtual
# console I usually leave idle.
#
#daemon,mail.*;\
# news.=crit;news.=err;news.=notice;\
# *.=debug;*.=info;\
# *.=notice;*.=warn /dev/tty8
EOF

  cat << 'EOF' > /etc/logrotate.d/syslog
/var/log/messages
{
 rotate 4
 weekly
 missingok
 notifempty
 compress
 delaycompress
 sharedscripts
 postrotate
  /usr/lib/rsyslog/rsyslog-rotate
 endscript
}
EOF

  # Disable AppArmor
  systemctl stop apparmor.service
  systemctl disable apparmor.service

  # Customize the prompt display
  cat << 'EOF' >> ~/.bashrc

# Modify the prompt.
if [ `id -u` = 0 ]; then
  PS1="\[\e[1;31m\]\u@\h \W\\$ \[\e[m\]"
else
  PS1="\[\e[1;36m\]\u@\h \W\\$ \[\e[m\]"
fi
EOF

  # Disable welcome message
  cat << EOF > ~/.hushlogin
exit
EOF

  # Control needrestart
  cat << 'EOF' > /etc/needrestart/conf.d/99_restart.conf
$nrconf{kernelhints} = '0';
$nrconf{restart} = 'a';
EOF

  # Install basic packages
  apt-get -y update
  apt-get -y install \
    curl \
    fping \
    git \
    neovim \
    nmap \
    tree \
    unzip \
    zip

  # NeoVim settings
  cat << 'EOF' >> ~/.bashrc

# NeoVim settings
alias vi="nvim"
alias vim="nvim"
EOF

  # Change IP address
  cat << 'EOF' > /usr/local/bin/chaddr
#!/usr/bin/env python3
import argparse
import subprocess

DEFAULT_DNS = ["1.1.1.1", "1.0.0.1"]
DEFAULT_INTERFACE = "ens160"

parser = argparse.ArgumentParser()
parser.add_argument("-a", "--address", type=str, required=True)
parser.add_argument("-g", "--gateway", type=str, required=True)
parser.add_argument("-d", "--dns", nargs="*", default=DEFAULT_DNS)
parser.add_argument("-i", "--interface", type=str, default=DEFAULT_INTERFACE)
args = parser.parse_args()

address = args.address
gateway = args.gateway
dns = args.dns
intf = args.interface
hostname = address[0 : address.index("/")].replace(".", "-")
subprocess.call("hostnamectl set-hostname " + hostname, shell=True)

netplan = f"""network:
  version: 2
  ethernets:
    {intf}:
      addresses:
        - {address}
      routes:
        - to: default
          via: {gateway}
      dhcp4: false
      nameservers:
        addresses:
"""
for _ in dns:
    netplan += f"          - {_}\n"
with open("/etc/netplan/99_config.yaml", "w") as f:
    f.write(netplan)

hosts = f"""
127.0.0.1 localhost {hostname}
127.0.1.1 localhost

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet {hostname}
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
"""
with open("/etc/hosts", "w") as f:
    f.write(hosts)
EOF
  chmod 755 /usr/local/bin/chaddr

  # Update system
  apt-get -y upgrade

  # Install uncmnt
  curl -L https://github.com/sig9org/uncmnt/releases/download/v0.0.2/uncmnt_v0.0.2_linux_amd64 -o /usr/local/bin/uncmnt && \
  chmod 755 /usr/local/bin/uncmnt

  # Install direnv
  curl -L https://github.com/direnv/direnv/releases/download/v2.35.0/direnv.linux-amd64 -o /usr/local/bin/direnv && \
  chmod 755 /usr/local/bin/direnv && \
  cat << 'EOF' >> ~/.bashrc
# direnv
export EDITOR=vim
eval "$(direnv hook bash)"
EOF

  # Install uv
  curl -LsSf https://astral.sh/uv/install.sh | sh

  # venv & direnv initialization script
  cat << 'EOF' > /usr/local/bin/venv
#!/bin/sh

uv venv
echo 'source .venv/bin/activate' > .envrc
direnv allow
EOF
  chmod 755 /usr/local/bin/venv

  # Install ripgrep
  curl -LO https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep_14.1.1-1_amd64.deb
  apt-get -y install ./ripgrep_14.1.1-1_amd64.deb
  rm *.deb

  # Install Terraform
  curl -LO https://releases.hashicorp.com/terraform/1.10.5/terraform_1.10.5_linux_amd64.zip
  unzip -d /usr/local/bin/ terraform_1.10.5_linux_amd64.zip
  rm -f *.zip
  rm /usr/local/bin/LICENSE.txt
}

function ubuntu_extra() {
  # Install Podman
  apt-get update
  apt-get -y install podman

  # Install Podman Compose
  apt-get -y install pipx
  pipx install podman-compose
  pipx ensurepath
}

declare RELEASE_FILE=/etc/os-release

if [ "$1" = "" ]
then
  if grep '^NAME="Ubuntu' "${RELEASE_FILE}" >/dev/null; then
    ubuntu_base
    reboot
  elif grep '^NAME="Amazon' "${RELEASE_FILE}" >/dev/null; then
    exit 1
  elif grep '^NAME="CentOS' "${RELEASE_FILE}" >/dev/null; then
    exit 1
  fi
fi

case "$1" in
  '-e'|'--extra')
    if grep '^NAME="Ubuntu' "${RELEASE_FILE}" >/dev/null; then
      ubuntu_base
	  ubuntu_extra
      reboot
    elif grep '^NAME="Amazon' "${RELEASE_FILE}" >/dev/null; then
      exit 1
    elif grep '^NAME="CentOS' "${RELEASE_FILE}" >/dev/null; then
      exit 1
    fi
    ;;
esac
