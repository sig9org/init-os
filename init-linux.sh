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

  # Update system
  apt-get -y upgrade

  # Install uncmnt
  curl -L https://github.com/sig9org/uncmnt/releases/download/v0.0.2/uncmnt_v0.0.2_linux_amd64 -o /usr/local/bin/uncmnt && \
  chmod 755 /usr/local/bin/uncmnt

  # Install direnv
  curl -L https://github.com/direnv/direnv/releases/download/v2.34.0/direnv.linux-amd64 -o /usr/local/bin/direnv && \
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
  curl -LO https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep_14.1.0-1_amd64.deb
  apt-get -y install ./ripgrep_14.1.0-1_amd64.deb
  rm *.deb

  # Install Terraform
  curl -LO https://releases.hashicorp.com/terraform/1.8.2/terraform_1.8.2_linux_amd64.zip
  unzip -d /usr/local/bin/ terraform_1.8.2_linux_amd64.zip
  rm -f *.zip
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
