#!/usr/bin/env bash

set -e

##
# Global variables
##

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD=$(tput bold)
NORM=$(tput sgr0)
UBUNTU_VER='Ubuntu 20.04'
BOOT_SPACE='51200'
SYSTEM_SPACE='358400'
ZEN_VER='7.1'
ZEN_REPO_KEY="http://keys.zentyal.org/zentyal-${ZEN_VER}-packages-org.asc"
ZEN_REPO_URL="deb [signed-by=/etc/apt/trusted.gpg.d/zentyal-7.1-packages-org.asc] https://packages.zentyal.org/zentyal ${ZEN_VER} main extra"
SURI_KEY='D7F87B2966EB736F'


##
# Functions
##

function check_ubuntu
{
  echo -e "\n${GREEN} - Checking Ubuntu version...${NC}"

  if ! lsb_release -d | egrep -q "${UBUNTU_VER}.?[0-9]? LTS$"
    then
      echo -e "${RED}  The version that you are using isn't valid. Zentyal requires ${UBUNTU_VER}.x LTS ${NC}"
      exit 1
  fi

  echo -e "${GREEN}${BOLD}...OK${NC}${NORM}";echo
}


function check_broken_packages
{
  echo -e "${GREEN} - Checking for broken packages...${NC}"

  if [[ $(dpkg -l | egrep -v '^ii|rc' | awk '{if(NR>5)print}' | wc -l) -gt 0 ]]
    then
      echo -e "${RED}  You have broken packages, trying to repair.${NC}"

      for i in {1..10}; do DEBIAN_FRONTEND=noninteractive dpkg --configure -a; done

      if [[ $(dpkg -l | egrep -v '^ii|rc' | awk '{if(NR>5)print}' | wc -l) -gt 0 ]]
        then
          echo -e "${RED}  Couln't fix the broken packages.${NC}"
          exit 1
      fi

      echo -e "${GREEN} Broken packages fixed. ${NORM}";echo
  fi

  echo -e "${GREEN}${BOLD}...OK${NC}${NORM}";echo
}


function check_available_packages
{
  echo -e "${GREEN} - Checking if the system is up-to-date...${NC}"

  apt -qq update
  if [[ $(apt list --upgradable 2> /dev/null | wc -l) -gt 1 ]]
    then
      echo -e "${RED}  Your server isn't up-to-date.${NC}"
      exit 1
  fi

  echo -e "${GREEN}${BOLD}...OK${NC}${NORM}";echo
}


function check_disk_space
{
  echo -e "${GREEN} - Checking for available disk space...${NC}"

  if [ $(df /boot | tail -1 | awk '{print $4}') -lt ${BOOT_SPACE} ];
    then
      echo -e "${RED}  Upgrade cannot be performed due to low disk space (less than 50MB available on /boot)${NC}"
      exit 1
  fi

  for partition in / /var
    do
      if [ $(df ${partition} | tail -1 | awk '{print $4}') -lt ${SYSTEM_SPACE} ];
        then
          echo -e "${RED}  Upgrade cannot be performed due to low partition space (less than 350MB available on '${partition}')${NC}"
          exit 1
      fi
    done

  echo -e "${GREEN}${BOLD}...OK${NC}${NORM}";echo
}


function check_connection
{
  local CHECK_DOMAIN='google.es'

  echo -e "${GREEN} - Checking the Internet connection...${NC}"

  if ! ping -4 -W 15 -q -c 5 ${CHECK_DOMAIN} > /dev/null
    then
      echo -e "${RED}  There are issues with the Internet resolution.${NC}"
      exit 1
  fi

  echo -e "${GREEN}${BOLD}...OK${NC}${NORM}";echo
}


function check_webadmin_port
{
  echo -e "${GREEN} - Checking Webadmin 8443/tcp port...${NC}"

  if ss -tunpl | grep -q '8443'
    then
      echo -e "${RED}  The port 8443/tcp is already in use.${NC}"
      exit 1
  fi

  echo -e "${GREEN}${BOLD}...OK${NC}${NORM}";echo
}


function check_requirements
{
  check_ubuntu
  check_broken_packages
  check_disk_space
  check_available_packages
  check_connection
  check_webadmin_port
}


function nic_names
{
    sed -i 's/#GRUB_HIDDEN_TIMEOUT=0/GRUB_HIDDEN_TIMEOUT=0/' /etc/default/grub
    sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"/\1 net.ifnames=0 biosdevname=0"/' /etc/default/grub
    update-grub
}

function zentyal_repository
{
  echo -e "${GREEN} - Adding Zentyal repository...${NC}\n"

  for url in packages.zentyal.com packages.zentyal.org archive.zentyal.org archive.zentyal.com
    do
      sed -i "/${url}/d" /etc/apt/sources.list

      for repo in $(find /etc/apt/sources.list.d/ -type f)
        do
          sed -i "/${url}/d" ${repo}
        done
    done

  # Set up Zentyal Development repository
  wget -q ${ZEN_REPO_KEY} -P /etc/apt/trusted.gpg.d/
  echo ${ZEN_REPO_URL} > /etc/apt/sources.list.d/zentyal.list

  ## Adding Suricata repositorio for zentyal-ips module
  if ! grep -qR 'http://ppa.launchpad.net/oisf/suricata-stable/ubuntu' /etc/apt/sources.list*
    then
      gpg --keyserver keyserver.ubuntu.com --recv-keys ${SURI_KEY}
      gpg --export ${SURI_KEY} > /etc/apt/trusted.gpg.d/suricata.gpg
      gpg --batch --yes --delete-keys ${SURI_KEY}
      echo "deb [signed-by=/etc/apt/trusted.gpg.d/suricata.gpg] http://ppa.launchpad.net/oisf/suricata-stable/ubuntu focal main" >> /etc/apt/sources.list.d/ips.list
  fi

  apt -qq update

  echo -e "${GREEN}${BOLD}...OK${NC}${NORM}";echo
}


function zentyal_gui
{
  echo -e "${GREEN} - Installing the graphical environment...${NC}\n"

  echo 'lxdm shared/default-x-display-manager select lxdm' | debconf-set-selections
  DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends ${ZEN_GUI}

  if [[ ! -f /etc/X11/default-display-manager ]]
    then
      ## For: Ubuntu Server 20.04 versions Live and Legacy
      echo -e "${GREEN}${BOLD}...OK${NC}${NORM}";echo
      continue
  fi

  CUR_GUI=$(cat /etc/X11/default-display-manager | xargs basename)

  case ${CUR_GUI} in
    gdm3) ## For: Ubuntu Desktop (Gnome) 20.04
      echo 'gdm3 shared/default-x-display-manager select lxdm' | debconf-set-selections
      DEBIAN_FRONTEND=noninteractive dpkg-reconfigure --force gdm3
      systemctl disable gdm3 lxdm
      which lxdm > /etc/X11/default-display-manager
      systemctl enable zentyal.lxdm
    ;;
    sddm) ## For: Lubuntu 20.04 and Kubuntu 20.04
      echo 'sddm shared/default-x-display-manager select lxdm' | debconf-set-selections
      DEBIAN_FRONTEND=noninteractive dpkg-reconfigure --force sddm
      systemctl disable sddm lxdm
      which lxdm > /etc/X11/default-display-manager
      systemctl enable zentyal.lxdm
    ;;
    lightdm) ## For: Xubuntu 20.04
      echo 'lightdm shared/default-x-display-manager select lxdm' | debconf-set-selections
      DEBIAN_FRONTEND=noninteractive dpkg-reconfigure --force lightdm
      systemctl disable lightdm lxdm
      which lxdm > /etc/X11/default-display-manager
      systemctl enable zentyal.lxdm
    ;;
  esac

  echo -e "${GREEN}${BOLD}...OK${NC}${NORM}";echo
}


function zentyal_installation
{
  echo -e "${GREEN} - Installing Zentyal...${NC}\n"

  apt remove -y netplan.io

  DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends zentyal zenbuntu-core

  echo -e "${GREEN}${BOLD}...OK${NC}${NORM}";echo

  if [[ -n ${ZEN_GUI} ]]
    then
      zentyal_gui
  fi

  touch /var/lib/zentyal/.commercial-edition
  touch /var/lib/zentyal/.license

  # TODO
  # nic_names

  echo -e "\n${GREEN}${BOLD}Installation complete, you can access the Zentyal Web Interface at:

  * https://<zentyal-ip-address>:8443/

  ${NC}${NORM}"
}


##
# Checks
##

if [[ ${EUID} -ne 0 ]]
  then
    echo -e "${RED}  The script must be run with 'sudo' rights.${NC}"
    exit 1
fi

echo -n "Do you want to install the Zentyal Graphical environment? (n|y) "
read ZEN_GUI

if [[ ${ZEN_GUI^} == 'Y' ]]
  then
    ZEN_GUI='zenbuntu-desktop'
elif [[ ${ZEN_GUI^} == 'N' ]]
  then
    ZEN_GUI=''
  else
    echo "Wrong answer. Please, type 'y' or 'n'."
    exit 1
fi


##
# Running the functions
##

check_requirements
zentyal_repository
zentyal_installation

