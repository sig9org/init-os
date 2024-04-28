#!/bin/bash

_usage() {      #(*1)
  echo "usage:"
  echo "${0} -h HOSTNAME -u USERNAME -p PUBLIC-KEY"
  exit 1
}

while getopts h:u:p: OPT
do
  case $OPT in
    "h" ) ENABLE_h="TRUE" ; VALUE_h=${OPTARG} ;;
    "u" ) ENABLE_u="TRUE" ; VALUE_u=${OPTARG} ;;
    "p" ) ENABLE_p="TRUE" ; VALUE_p=${OPTARG} ;;
    :|\?) _usage;;
  esac
done

[ "${ENABLE_h}" != "TRUE" ] && _usage
[ "${ENABLE_u}" != "TRUE" ] && _usage
[ "${ENABLE_p}" != "TRUE" ] && _usage

hostnamectl set-hostname ${VALUE_h}
timedatectl set-timezone Asia/Tokyo

echo "export PS1='\[\033[01;36m\]\u@\H\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '" >> /etc/profile
echo "export PS1='\[\033[01;31m\]\u@\H\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\\$ '" >> /root/.bashrc

sed -i -e "s/^%wheel\tALL=(ALL)\tALL/# %wheel\tALL=(ALL)\tALL/g" /etc/sudoers
sed -i -e "s/^# %wheel\tALL=(ALL)\tNOPASSWD: ALL/%wheel\tALL=(ALL)\tNOPASSWD: ALL/g" /etc/sudoers
sed -i -e "s/#PermitRootLogin yes/PermitRootLogin no/g" /etc/ssh/sshd_config
sed -i -e "s/alias rm='rm -i'/#alias rm='rm -i'/g" /root/.bashrc
sed -i -e "s/alias cp='cp -i'/#alias cp='cp -i'/g" /root/.bashrc
sed -i -e "s/alias mv='mv -i'/#alias mv='mv -i'/g" /root/.bashrc

useradd ${VALUE_u}
usermod -aG wheel ${VALUE_u}
mkdir /home/${VALUE_u}/.ssh/
chmod 700 /home/${VALUE_u}/.ssh/
cat << EOF > /home/${VALUE_u}/.ssh/authorized_keys
${VALUE_p}
EOF
chmod 600 /home/${VALUE_u}/.ssh/authorized_keys
chown -R ${VALUE_u}:${VALUE_u} /home/${VALUE_u}/.ssh/

yum -y update
yum clean all
history -c

reboot

