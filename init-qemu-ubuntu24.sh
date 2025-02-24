#!/bin/bash

# Install basic packages
apt-get update
apt-get install -y \
  curl \
  fping \
  git \
  gpg \
  neovim \
  nmap \
  sudo \
  traceroute \
  tree \
  unzip \
  wget \
  zip

# Disable AppArmor
systemctl stop apparmor.service
systemctl disable apparmor.service

# Timezone & NTP
timedatectl set-timezone Asia/Tokyo
cat << EOF >> /etc/systemd/timesyncd.conf
NTP=162.159.200.123 162.159.200.1
EOF

# SSH
sed -i -e "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/g" /etc/ssh/sshd_config
sed -i -e "s/#ClientAliveInterval 0/ClientAliveInterval 60/g" /etc/ssh/sshd_config
sed -i -e "s/#ClientAliveCountMax 3/ClientAliveCountMax 5/g" /etc/ssh/sshd_config

cat << EOF > /etc/ssh/ssh_config.d/99_lab.conf
KexAlgorithms +diffie-hellman-group1-sha1
Ciphers aes128-cbc,aes256-ctr
StrictHostKeyChecking no
UserKnownHostsFile=/dev/null
EOF

# Enable "/var/log/messages"
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

# Install mise
apt update -y
install -dm 755 /etc/apt/keyrings
wget -qO - https://mise.jdx.dev/gpg-key.pub | gpg --dearmor | tee /etc/apt/keyrings/mise-archive-keyring.gpg 1> /dev/null
echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=amd64] https://mise.jdx.dev/deb stable main" | tee /etc/apt/sources.list.d/mise.list
apt update
apt install -y mise

# venv script
tee /usr/local/bin/venv <<EOF
#!/usr/bin/env bash

mise use python@latest
uv venv .venv

cat << EOL >> mise.toml

[env]
_.python.venv = ".venv"
EOL

cat << EOL >> taskfile.yml
version: '3'

tasks:
  default:
    cmds:
      - task --list

  build:
    aliases: [b]
    desc: Build
    cmds:
      - pyinstaller build.spec

  format:
    aliases: [f]
    desc: Format the source code
    cmds:
      - ruff format .
      - ruff check . --fix

  lint:
    aliases: [l]
    desc: Static analysis
    cmds:
      - ruff check .
      - mypy .

  test:
    aliases: [t]
    desc: Test
    cmds:
      - pytest .
EOL
EOF

# Initialization script
cat << 'EOF' >> /usr/local/bin/init-img.sh
#!/bin/bash

chmod 755 /usr/local/bin/venv

cat << 'EOL' >> ~/.bashrc
eval "$(/usr/bin/mise activate bash)"
EOL

echo 'exit' > ~/.hushlogin

cat << 'EOL' >> ~/.bashrc

# NeoVim settings
alias vi="nvim"
alias vim="nvim"
EOL

mise install python@latest
mise use -g python@latest

mise install task@latest
mise use -g task@latest

mise install terraform@latest
mise use -g terraform@latest

mise install ripgrep@latest
mise use -g ripgrep@latest

mise install ruff@latest
mise use -g ruff@latest

mise install uv@latest
mise use -g uv@latest

mise install xh@latest
mise use -g xh@latest

rm -rf /usr/local/bin/init-img.sh
EOF

# Clean up
apt clean all
history -c