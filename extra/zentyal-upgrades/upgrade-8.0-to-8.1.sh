#!/bin/bash

# Enable debug
# set -x

####
## Variables
####

SOURCES=/etc/apt/sources.list
UPGRADE_FILE=/var/lib/zentyal/.upgrade-finished
TMPFILE=/tmp/packages-list
LOG_FILE="/var/log/zentyal/upgrade.log"
LOG_DATE="$(date "+%d-%m-%Y %H:%M:%S") "
CURCODE='jammy'
DSTCODE='noble'
CURMAJORV=$(dpkg -l|grep zentyal-core | awk '{print $3}' | cut -d'.' -f1)
CURMINORV=$(dpkg -l|grep zentyal-core | awk '{print $3}' | cut -d'.' -f2)
DESTMAJOR=$(curl -s https://update.zentyal.org/update-from-${CURMAJORV}.${CURMINORV}.txt | cut -d '.' -f1)
DESTMINOR=$(curl -s https://update.zentyal.org/update-from-${CURMAJORV}.${CURMINORV}.txt | cut -d '.' -f2)
CURRV="${CURMAJORV}.${CURMINORV}"
DESTV="${DESTMAJOR}.${DESTMINOR}"
ZEN_REPO_KEY_URL='https://keys.zentyal.org/'
BACKUP_DB_WEBMAIL='/var/lib/zentyal/backup-sogo-upgrade-81.sql'

####
## Functions
####

function checkZentyalVersion
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ... Checking the zentyal-core version" | tee -a ${LOG_FILE}

    if [ $CURMAJORV -gt $DESTMAJOR ]; then
        echo "$(date '+%d-%m-%Y %H:%M:%S') ...... ERROR: Your system is up to date" | tee -a ${LOG_FILE}
        exit 130
    elif [ $DESTMAJOR -gt $CURMAJORV ]; then
        echo "$(date '+%d-%m-%Y %H:%M:%S') ... OK" | tee -a ${LOG_FILE}
    elif [ $CURMINORV -gt $DESTMINOR ] || [ $CURMINORV -eq $DESTMINOR ]; then
        echo "$(date '+%d-%m-%Y %H:%M:%S') ...... ERROR: Your system is up to date" | tee -a ${LOG_FILE}
        exit 130
    fi

    echo "$(date '+%d-%m-%Y %H:%M:%S') ... OK" | tee -a ${LOG_FILE}
}

function checkZentyalStatusPackages
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ... Checking the status of Zentyal packages" | tee -a ${LOG_FILE}

    local PKG_REGEX='^(zentyal-|language-package-zentyal-|zenbuntu-)'
    local ZENTYAL_PKGS=""
    local INVALID_ZENTYAL_PKGS=""

    ZENTYAL_PKGS=$(dpkg -l | awk -v re="${PKG_REGEX}" '$2 ~ re')
    INVALID_ZENTYAL_PKGS=$(echo "${ZENTYAL_PKGS}" | awk '$1 != "ii" && $1 != "rc"')
    if [[ -n "${INVALID_ZENTYAL_PKGS}" ]]; then
        echo "$(date '+%d-%m-%Y %H:%M:%S') ...... ERROR: Some Zentyal packages are not correctly installed (status must be \"ii\", \"rc\" is ignored)" | tee -a ${LOG_FILE}
        echo "${INVALID_ZENTYAL_PKGS}" | tee -a ${LOG_FILE}
        exit 130
    fi

    echo "$(date '+%d-%m-%Y %H:%M:%S') ... OK" | tee -a ${LOG_FILE}
}

function checkUbuntuVersion
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ... Checking the version of Ubuntu" | tee -a ${LOG_FILE}

    if [[ "$(lsb_release -sc)" != "${CURCODE}" ]]; then
        echo "$(date '+%d-%m-%Y %H:%M:%S') ...... ERROR: Your system is running an unsupported version of Ubuntu for the upgrade" | tee -a ${LOG_FILE}
        exit 130
    fi

    echo "$(date '+%d-%m-%Y %H:%M:%S') ... OK" | tee -a ${LOG_FILE}
}

function checkIfCommercial
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ... Checking if the server is a Commercial edition" | tee -a ${LOG_FILE}

    if [ -f '/var/lib/zentyal/.commercial-edition' ] && [ -s '/var/lib/zentyal/.license' ];
    then
        echo "$(date '+%d-%m-%Y %H:%M:%S') ...... The server is using a Commercial Edition" | tee -a ${LOG_FILE}
        export COMMERCIAL=1
    else
        echo "$(date '+%d-%m-%Y %H:%M:%S') ...... The server is using a Development Edition" | tee -a ${LOG_FILE}
    fi

    echo "$(date '+%d-%m-%Y %H:%M:%S') ... OK" | tee -a ${LOG_FILE}
}

function checkDiskSpace
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ... Checking for available disk space" | tee -a ${LOG_FILE}

    if [ $(df /boot | tail -1 | awk '{print $4}') -lt 250000 ];
    then
        echo "$(date '+%d-%m-%Y %H:%M:%S') ...... ERROR: Upgrade cannot be performed due to insufficient disk space (less than 250 MB available on /boot)" | tee -a ${LOG_FILE}
        exit 130
    fi

    for i in / /var
    do
        if [ `df $i | tail -1 | awk '{print $4}'` -lt 3072000 ];
        then
            echo "$(date '+%d-%m-%Y %H:%M:%S') ...... ERROR: Upgrade cannot be performed due to insufficient disk space (less than 3GB available on $i)" | tee -a ${LOG_FILE}
            exit 130
        fi
    done

    echo "$(date '+%d-%m-%Y %H:%M:%S') ... OK" | tee -a ${LOG_FILE}
}

function checkInternetAccess
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ... Checking if there is Internet" | tee -a ${LOG_FILE}

    if ! ping -4 -W 15 -q -c 5 google.es 2> /dev/null; then
        echo "$(date '+%d-%m-%Y %H:%M:%S') ...... ERROR: There is not Internet connection and it is required for the upgrade" | tee -a ${LOG_FILE}
        exit 130
    fi

    echo "$(date '+%d-%m-%Y %H:%M:%S') ... OK" | tee -a ${LOG_FILE}
}

function checkPendingPackages
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ... Checking if the server is up-to-date" | tee -a ${LOG_FILE}

    IFS=';' read updates security_updates < <(/usr/lib/update-notifier/apt-check 2>&1)
    if (( $updates != 0 )) && (( $security_updates != 0 )); then
        echo "$(date '+%d-%m-%Y %H:%M:%S') ...... ERROR: There are $updates updates available and $security_updates security updates available, please, install them before to upgrade your system" | tee -a ${LOG_FILE}
        exit 130
    fi

    echo "$(date '+%d-%m-%Y %H:%M:%S') ... OK" | tee -a ${LOG_FILE}
}

function checkUbuntuRepositories
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ... Setting Ubuntu repositories if not present" | tee -a ${LOG_FILE}

    if ! grep -v "^#" $SOURCES | grep -q "ubuntu.com"
    then
        echo "$(date '+%d-%m-%Y %H:%M:%S') ...... Adding repositories" | tee -a ${LOG_FILE}

        echo "deb http://archive.ubuntu.com/ubuntu/ $DSTCODE main restricted universe multiverse" >> $SOURCES
        echo "deb http://archive.ubuntu.com/ubuntu/ $DSTCODE-updates main restricted universe multiverse" >> $SOURCES
        echo "deb http://security.ubuntu.com/ubuntu/ $DSTCODE-security main restricted universe multiverse" >> $SOURCES
    fi

    echo "$(date '+%d-%m-%Y %H:%M:%S') ... OK" | tee -a ${LOG_FILE}
}

function repairPkgs
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... Trying to fix the following broken packages" | tee -a ${LOG_FILE}

    local PKGS=$(dpkg -l | grep -vE '^(ii|rc|hi)'| awk '{ if ( NR > 5  ) { print $2} }')
    for pkg in ${PKGS}; do
        echo "...... Broken package: ${pkg}" | tee -a ${LOG_FILE}
    done

    for i in {1..10}; do
        dpkg --configure --force-confdef -a
    done

    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... OK" | tee -a ${LOG_FILE}
}

function checkBrokenPackages
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ... Checking if there are broken packages" | tee -a ${LOG_FILE}

    dpkg -l | grep 'zentyal-'; echo ""
    dpkg -l | egrep -v '^ii' | awk '{ if ( NR > 5  ) { print } }'; echo ""
    touch $TMPFILE && dpkg -l | grep -E '^[A-Za-z]{2} ' > $TMPFILE

    if grep -vE '^(ii|rc|ic|hi)' $TMPFILE
    then
        if [[ $(systemctl is-active redis) != 'active' ]]
        then
            echo "$(date '+%d-%m-%Y %H:%M:%S') ...... Restarting Redis" | tee -a ${LOG_FILE}
            systemctl restart redis
        fi
        echo "$(date '+%d-%m-%Y %H:%M:%S') ...... There are broken packages" | tee -a ${LOG_FILE}
        repairPkgs
    fi
    rm -f $TMPFILE

    echo "$(date '+%d-%m-%Y %H:%M:%S') ... OK" | tee -a ${LOG_FILE}
}

function checkGPG
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ... Looking for gnupg package" | tee -a ${LOG_FILE}

    dpkg -s gnupg &> /dev/null
    if [ $? -ne 0 ]; then
        echo "$(date '+%d-%m-%Y %H:%M:%S') ...... Package is NOT installed! Trying to install it" | tee -a ${LOG_FILE};echo
        apt install gnupg -y
    fi

    echo "$(date '+%d-%m-%Y %H:%M:%S') ... OK" | tee -a ${LOG_FILE}
}

function checkZentyalMySQL
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ... Checking Zentyal's MySQL db" | tee -a ${LOG_FILE}

    mysqlcheck --databases zentyal

    echo "$(date '+%d-%m-%Y %H:%M:%S') ... OK" | tee -a ${LOG_FILE}
}

function cleanPreviousUpgrade
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ... Cleaning $UPGRADE_FILE if exists" | tee -a ${LOG_FILE}

    if [ -f $UPGRADE_FILE ]
    then
        rm -f $UPGRADE_FILE
    fi

    echo "$(date '+%d-%m-%Y %H:%M:%S') ... OK" | tee -a ${LOG_FILE}
}

function prepareUpgrade
{
    checkZentyalVersion
    checkZentyalStatusPackages
    checkUbuntuVersion
    checkIfCommercial
    checkDiskSpace
    checkInternetAccess
    checkPendingPackages
    checkUbuntuRepositories
    checkBrokenPackages
    checkGPG
    checkZentyalMySQL
    cleanPreviousUpgrade
}

function ensureInternet
{
    if ! ping -4 -W 15 -q -c 5 google.es 2> /dev/null; then
        zs network restart
    fi
}

function upgradePackages
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ... Upgrading the system"

    export DEBIAN_FRONTEND=noninteractive
    apt update
    apt dist-upgrade -y -o DPkg::Options::="--force-overwrite" -o DPkg::Options::="--force-confdef"

    echo "$(date '+%d-%m-%Y %H:%M:%S') ... OK" | tee -a ${LOG_FILE}
    checkBrokenPackages
    apt clean
}

function lkActivation
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... Updating the license key version" | tee -a ${LOG_FILE}

    local GET_ZENTYAL_VERSION=$(dpkg -l zentyal-core | tail -1 | awk '{print $3}' | cut -d '.' -f1,2)
    if [[ ${GET_ZENTYAL_VERSION} != "${DESTV}" ]]; then
        echo "$(date '+%d-%m-%Y %H:%M:%S') ......... ERROR: Cannot activate the license key because the 'zentyal-core' package does not match with the destination version" | tee -a ${LOG_FILE}
        return
    fi

    local API_URL='https://ucp.zentyal.com/api/v2/licenses/upgrade-version'
    local LK="$(cat /var/lib/zentyal/.license)"
    local LK_ID="$(cat /var/lib/zentyal/.server_uuid)"
    local RESPONSE_DATA_FILE_TMP="/tmp/license_response_data.tmp"

    if [[ -z "${LK}" || -z "${LK_ID}" ]]; then
        echo "$(date '+%d-%m-%Y %H:%M:%S') ......... ERROR: Missing license or server UUID file" | tee -a "${LOG_FILE}"
        return
    fi

    local JSON_STRING=$(jq -n \
    --arg id "${LK_ID}" \
    --arg lk "${LK}" \
    --arg v "${DESTV}" \
    '{
        server_uuid: $id,
        license_key: $lk,
        destination_version: $v
    }')

    mv /var/lib/zentyal/.server_uuid /var/lib/zentyal/.product_uuid

    local REQUEST=$(/usr/bin/timeout 30 /usr/bin/curl -s -X POST -H "Content-Type: application/json" -d "$JSON_STRING" $API_URL -w "%{http_code}" -o $RESPONSE_DATA_FILE_TMP)

    if [[ ${REQUEST} -ne 200 ]]; then
        local ERROR_MESSAGE=$(cat ${RESPONSE_DATA_FILE_TMP} | jq -r ".message")
        echo "$(date '+%d-%m-%Y %H:%M:%S') ......... ERROR: The license key could not be updated. API response message: ${ERROR_MESSAGE}" | tee -a ${LOG_FILE}
        rm -f ${RESPONSE_DATA_FILE_TMP}
        return
    fi

    rm -f ${RESPONSE_DATA_FILE_TMP}

    if ! /usr/share/zentyal/check_license ${LK};
    then
        echo "$(date '+%d-%m-%Y %H:%M:%S') ......... ERROR: The license key validation failed." | tee -a ${LOG_FILE}
        return
    fi

    zs webadmin restart
    apt update

    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... OK" | tee -a ${LOG_FILE}
}

function prepareUbuntuRepository
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... Setting new Ubuntu repositories" | tee -a ${LOG_FILE}

    sed -i "s/^deb-src/#deb-src/g" /etc/apt/sources.list
    sed -i "s/$CURCODE/$DSTCODE/g" /etc/apt/sources.list

    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... OK" | tee -a ${LOG_FILE}
}

function prepareZentyalRepository
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... Adding repository for Zentyal" | tee -a ${LOG_FILE}

    # Remove existing Zentyal and Suricata repositories
    for url in packages.zentyal.com packages.zentyal.org archive.zentyal.org archive.zentyal.com suricata-stable
    do
        sed -i "/${url}/d" /etc/apt/sources.list

        for repo in $(find /etc/apt/sources.list.d/ -type f)
        do
            sed -i "/${url}/d" ${repo}
        done
    done

    if [[ -n ${COMMERCIAL} ]]; then
        echo "$(date '+%d-%m-%Y %H:%M:%S') ........ Adding Commercial repository..." | tee -a ${LOG_FILE}
        wget -q ${ZEN_REPO_KEY_URL}/zentyal-${DESTV}-packages-com.asc -P /etc/apt/trusted.gpg.d/
        echo "deb [signed-by=/etc/apt/trusted.gpg.d/zentyal-${DESTV}-packages-com.asc] https://packages.zentyal.com/zentyal-qa ${DESTV} main extra" > /etc/apt/sources.list.d/zentyal-qa.list
        rm -f /etc/apt/sources.list.d/zentyal.list
    else
        echo "$(date '+%d-%m-%Y %H:%M:%S') ........ Adding Development repository..." | tee -a ${LOG_FILE}
        wget -q ${ZEN_REPO_KEY_URL}/zentyal-${DESTV}-packages-org.asc -P /etc/apt/trusted.gpg.d/
        echo "deb [signed-by=/etc/apt/trusted.gpg.d/zentyal-${DESTV}-packages-org.asc] https://packages.zentyal.org/zentyal ${DESTV} main extra" > /etc/apt/sources.list.d/zentyal.list
        rm -f /etc/apt/sources.list.d/zentyal-qa.list
    fi

  echo "$(date '+%d-%m-%Y %H:%M:%S') ...... OK" | tee -a ${LOG_FILE}
}

function prepareDockerRepository
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... Adding Docker repository" | tee -a ${LOG_FILE}

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod 0644 /etc/apt/keyrings/docker.asc
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" >> /etc/apt/sources.list.d/zentyal.list

    if [[ -f /etc/apt/sources.list.d/docker.list ]]; then
        rm /etc/apt/sources.list.d/docker.list
    fi

    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... OK" | tee -a ${LOG_FILE}
}

function prepareFirefoxRepository
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... Adding Firefox repository" | tee -a ${LOG_FILE}

    wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- > /etc/apt/trusted.gpg.d/packages.mozilla.org.asc
    chmod 0644 /etc/apt/trusted.gpg.d/packages.mozilla.org.asc
    echo "deb [signed-by=/etc/apt/trusted.gpg.d/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" >> /etc/apt/sources.list.d/zentyal.list

    if [[ -f /etc/apt/sources.list.d/mozilla.list ]]; then
        rm /etc/apt/sources.list.d/mozilla.list
    fi

    if [[ -f '/etc/apt/preferences.d/FIREFOX_REPO_PREFERENCE_NAME' ]]; then
        rm -f /etc/apt/preferences.d/FIREFOX_REPO_PREFERENCE_NAME
    fi

cat <<EOF > /etc/apt/preferences.d/mozilla
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... OK" | tee -a ${LOG_FILE}
}

function zentyalRepositories
{
    prepareZentyalRepository
    prepareFirefoxRepository
    prepareDockerRepository
}

function newFormatUbuntuRepository
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ... Changing the Ubuntu repository format for Ubuntu ${DSTCODE}" | tee -a ${LOG_FILE}

cat <<EOF > /etc/apt/sources.list.d/ubuntu.sources
Types: deb
URIs: http://es.archive.ubuntu.com/ubuntu/
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu/
Suites: noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

    echo '# Ubuntu sources have moved to /etc/apt/sources.list.d/ubuntu.sources' > /etc/apt/sources.list

    echo "$(date '+%d-%m-%Y %H:%M:%S') ... OK" | tee -a ${LOG_FILE}
}

function configurationEjabberd
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... Configuring Ejabberd module" | tee -a ${LOG_FILE}

    if [[ ! -L /etc/apparmor.d/disable/usr.sbin.ejabberdctl ]];
    then
        ln -s /etc/apparmor.d/usr.sbin.ejabberdctl /etc/apparmor.d/disable/
    fi

    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... OK" | tee -a ${LOG_FILE}
}

function configurationDHCP
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... Configuring DHCP module" | tee -a ${LOG_FILE}

    if [[ -L /etc/apparmor.d/disable/usr.sbin.dhcpd ]]; then
        unlink /etc/apparmor.d/disable/usr.sbin.dhcpd
        apparmor_parser -r /etc/apparmor.d/usr.sbin.dhcpd
    fi

    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... OK" | tee -a ${LOG_FILE}
}

function configurationMail
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... Configuring Mail module" | tee -a ${LOG_FILE}

    if [[ -f /etc/cron.d/ebox-mail ]]; then
        rm -f /etc/cron.d/ebox-mail
    fi

    if [[ -d  /etc/cron.daily/zentyal-autoexpunge/ ]]; then
        rm -rf /etc/cron.daily/zentyal-autoexpunge/
    fi

    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... OK" | tee -a ${LOG_FILE}
}

function workaroundSogo
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... Applying workaround for Sogo package" | tee -a ${LOG_FILE}

    mysqldump -u root -p$(cat /var/lib/zentyal/conf/zentyal-mysql.passwd) sogo > ${BACKUP_DB_WEBMAIL}
    if [[ $(du -s ${BACKUP_DB_WEBMAIL} | awk '{print $1}') -lt 4 ]]; then
        echo "$(date '+%d-%m-%Y %H:%M:%S') ERROR: Zentyal upgrade FAILED. Could not export Sogo database, full log at ${LOG_FILE} " | tee -a ${LOG_FILE}
        exit 130
    else
        echo "$(date '+%d-%m-%Y %H:%M:%S') ........ Sogo database backup located at '${BACKUP_DB_WEBMAIL}'" | tee -a ${LOG_FILE}
    fi

    apt-mark unhold zentyal-sogo
    for pkg in zentyal-groupware zentyal-all; do
        if dpkg-query -W -f='${db:Status-Status}\n' "$pkg" 2>/dev/null | grep -qx installed; then
            if [[ -z "${ZENTYAL_WEBMAIL_METAPACKAGES}" ]]; then
                export ZENTYAL_WEBMAIL_METAPACKAGES="${pkg}"
            else
                export ZENTYAL_WEBMAIL_METAPACKAGES="${ZENTYAL_WEBMAIL_METAPACKAGES} ${pkg}"
            fi
            apt-mark unhold "$pkg"
        fi
    done

    SOGO_PKGS=$(dpkg -l | egrep '^ii.*(sope|sogo|libwbxml2|zentyal-sogo)' | egrep -v 'zentyal' | awk '{print $2}')
    apt remove -o DPkg::Options::=--force-confdef -y ${SOGO_PKGS}

    prepareZentyalRepository

    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... OK" | tee -a ${LOG_FILE}
}

function configurationSogo
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... Installing Sogo module" | tee -a ${LOG_FILE}

    apt install -o DPkg::Options::=--force-confdef -y zentyal-sogo ${ZENTYAL_WEBMAIL_METAPACKAGES}

    # https://sogo.nu/files/docs/SOGoInstallationGuide.html#_upgrading
    bash /usr/share/doc/sogo/sql-update-5.5.1_to_5.6.0.sh
    bash /usr/share/doc/sogo/sql-update-5.8.4_to_5.9.0.sh

    systemctl unmask sogo
    zs sogo start

    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... OK" | tee -a ${LOG_FILE}
}

function configurationAntivirus
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... Configuring Antivirus module" | tee -a ${LOG_FILE}

    if [[ -f /etc/cron.d/clamav-freshclam.dpkg-old ]]; then
        rm -f /etc/cron.d/clamav-freshclam.dpkg-old
    fi

    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... OK" | tee -a ${LOG_FILE}
}

function configurationProxy
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... Configuring Proxy module" | tee -a ${LOG_FILE}

    if id e2guardian && ! groups clamav | grep -q e2guardian; then
        # Add clamav user to group e2guardian.
        usermod -aG e2guardian clamav
    fi

    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... OK" | tee -a ${LOG_FILE}
}

function configurationDesktop
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... Configuring zenbuntu-desktop module" | tee -a ${LOG_FILE}

    # Remove incorrect file
    if [[ -f /etc/apt/preferences.d/FIREFOX_REPO_PREFERENCE_NAME ]]; then
        rm -f /etc/apt/preferences.d/FIREFOX_REPO_PREFERENCE_NAME
    fi

    touch /var/lib/zentyal/.desktop-post-upgrade-81

cat <<EOF >> /etc/rc.local
if [ -f /var/lib/zentyal/.desktop-post-upgrade-81 ]; then
    /usr/share/zenbuntu-desktop/x11-setup
    systemctl restart zentyal.lxdm
    rm -f /var/lib/zentyal/.desktop-post-upgrade-81
    cp /usr/share/zenbuntu-core/rc.local /etc/rc.local
fi

exit 0
EOF

    sed -i '20d' /etc/rc.local

    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... OK" | tee -a ${LOG_FILE}
}

function setDomainLevel
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... Setting current Domain and Forest functional level" | tee -a ${LOG_FILE}

    GET_DOMAIN_LEVEL=$(samba-tool domain level show 2>/dev/null \
        | grep -m1 '^Domain function level:' \
        | sed 's/.*(Windows) //; s/ /_/g')

    if [[ -z "$GET_DOMAIN_LEVEL" ]]; then
        echo "ERROR: Couldn't get the Domain Function Level." >&2
        exit 1
    fi

    for KEY in samba/ro/DomainSettings/keys/form samba/conf/DomainSettings/keys/form; do
        CURRENT_JSON=$(redis-cli get "$KEY")

        if [[ -n "$CURRENT_JSON" ]] && echo "$CURRENT_JSON" | jq -e . >/dev/null 2>&1; then
            NEW_JSON=$(echo "$CURRENT_JSON" | jq -c --arg lvl "$GET_DOMAIN_LEVEL" '.domainlevel = $lvl')
        else
            NEW_JSON=$(jq -cn --arg lvl "$GET_DOMAIN_LEVEL" '{domainlevel: $lvl}')
        fi

        redis-cli set "$KEY" "$NEW_JSON"
    done

    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... OK" | tee -a ${LOG_FILE}
}

function configurationDomainController
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... Configuring Domain Controller module" | tee -a ${LOG_FILE}

    if dpkg -l | grep -qo 'ii  auth-client-config'; then
        apt remove -y auth-client-config
    fi

    if [[ -d /etc/auth-client-config/ ]]; then
        rm -rf /etc/auth-client-config
    fi

    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... OK" | tee -a ${LOG_FILE}
}

function preUbuntuUpgrade
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ... Pre configuration before upgrading Ubuntu" | tee -a ${LOG_FILE}

    # Ejabberd configuration
    if dpkg -l | grep -qo 'ii  zentyal-jabber '; then
        configurationEjabberd
    fi

    # Needed to avoid issues with the DHCP client during the upgrade
    if [[ ! -L /etc/apparmor.d/disable/sbin.dhclient ]]; then
        ln -s /etc/apparmor.d/sbin.dhclient /etc/apparmor.d/disable/
        systemctl restart apparmor
    fi

    prepareUbuntuRepository
    zentyalRepositories

    echo "$(date '+%d-%m-%Y %H:%M:%S') ... OK" | tee -a ${LOG_FILE}
}

function upgradeUbuntu
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ... Upgrading Ubuntu" | tee -a ${LOG_FILE}

    for log in /var/log/zentyal/zentyal.log /var/log/syslog /var/log/dpkg.log; do
        echo "## Updating Ubuntu packages" | tee -a ${log}
    done

    # Needed to avoid issues during the upgrade
    apt-mark hold ${PKG}

    if dpkg -l | grep -qo 'hi  zentyal-sogo '; then
        export WEBMAIL=1
        workaroundSogo
    fi

    upgradePackages

    ensureInternet

    if [[ "$(lsb_release -cs)" != "${DSTCODE}" ]]; then
        echo "$(date '+%d-%m-%Y %H:%M:%S') ERROR: Ubuntu upgrade FAILED. Full log at ${LOG_FILE} "
        exit 130
    fi

    echo "$(date '+%d-%m-%Y %H:%M:%S') ... OK" | tee -a ${LOG_FILE}
}

function postUbuntuUpgrade
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ... Post configuration after upgrading Ubuntu" | tee -a ${LOG_FILE}

    newFormatUbuntuRepository

    echo "$(date '+%d-%m-%Y %H:%M:%S') ... OK" | tee -a ${LOG_FILE}
}

function preZentyalUpgrade
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ... Pre configuration before upgrading Zentyal" | tee -a ${LOG_FILE}

    zentyalRepositories

    # Proxy configuration
    if dpkg -l | grep -qo 'hi  zentyal-squid '; then
        configurationProxy
    fi

    # Domain Controller configuration
    if dpkg -l | grep -qo 'hi  zentyal-samba '; then
        setDomainLevel
    fi

    echo "$(date '+%d-%m-%Y %H:%M:%S') ... OK" | tee -a ${LOG_FILE}
}

function upgradeZentyal
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ... Upgrading Zentyal" | tee -a ${LOG_FILE}

    for log in /var/log/zentyal/zentyal.log /var/log/syslog /var/log/dpkg.log; do
        echo "## Updating Zentyal packages" | tee -a ${log}
    done

    apt-mark unhold ${PKG}

    # Stopping IPS module to prevent avoid connection issues during the upgrade
    if dpkg -l | grep -qo 'ii  zentyal-ips '; then
        zs ips stop
    fi

    ensureInternet
    upgradePackages

    # Check if main zentyal-core package was upgraded
    if [[ "$(dpkg -l | grep zentyal-core | awk '{print $3}' | cut -d '.' -f1,2)" != "${DESTV}" ]]; then
        echo "$(date '+%d-%m-%Y %H:%M:%S') ERROR: Zentyal upgrade FAILED. Full log at ${LOG_FILE}"
        exit 130
    fi

    echo "$(date '+%d-%m-%Y %H:%M:%S') ... OK" | tee -a ${LOG_FILE}
}

function postZentyalUpgrade
{
    echo "$(date '+%d-%m-%Y %H:%M:%S') ... Post configuration after upgrading Zentyal" | tee -a ${LOG_FILE}

    # Remove old repositories
    rm -f /etc/apt/sources.list.d/{zentyal*,docker,mozilla}.list

    # Ensure unattended-upgrade is disabled
    if [[ -f '/etc/apt/apt.conf.d/20auto-upgrades' ]]; then
        sed -i 's/1/0/' /etc/apt/apt.conf.d/20auto-upgrades
    fi

    # Restore rc.local file
    cp /usr/share/zenbuntu-core/rc.local /etc/rc.local

    # Enable again the DHCP client AppArmor profile
    if [[ -L /etc/apparmor.d/disable/sbin.dhclient ]]; then
        unlink /etc/apparmor.d/disable/sbin.dhclient
    fi

    # DHCP configuration
    if dpkg -l | grep -qo '  zentyal-dhcp '; then
        configurationDHCP
    fi

    # Antivirus configuration
    if dpkg -l | grep -qo '  zentyal-antivirus '; then
        configurationAntivirus
    fi

    # Mail configuration
    if dpkg -l | grep -qo '  zentyal-mail '; then
        configurationMail
    fi

    # zenbuntu-desktop configuration
    if dpkg -l | grep -qo '  zenbuntu-desktop '; then
        configurationDesktop
    fi

    if [[ ${COMMERCIAL} -eq 1 ]]; then
        lkActivation
    fi

    # Domain Controller configuration
    if dpkg -l | grep -qo '  zentyal-samba '; then
        configurationDomainController
    fi

    # Sogo configuration
    if [[ ${WEBMAIL} -eq 1 ]]; then
        configurationSogo
    fi

    ensureInternet

    # Purge all no longer needed running services
    dpkg -l | grep 'zentyal-' | cut -d' ' -f3 | xargs apt-mark manual
    apt autoremove --purge -y -o DPkg::Options::="--force-confdef"
    dpkg --configure -a --force-confdef
    apt -f install -y -o DPkg::Options::="--force-confdef"
    checkBrokenPackages

    # Remove packages in 'rc' or 'ic' status
    local PKG_TO_REMOVE=$(dpkg -l | egrep '^(rc|ic)' | awk '{print $2}')
    if [[ -n ${PKG_TO_REMOVE} ]] && [[ ! $(echo $PKG_TO_REMOVE | egrep zentyal) ]]; then
        echo "$(date '+%d-%m-%Y %H:%M:%S') ...... Removing packages that are not longer needed" | tee -a ${LOG_FILE}
        dpkg --purge ${PKG_TO_REMOVE}
    else
        echo "$(date '+%d-%m-%Y %H:%M:%S') ...... No packages to remove" | tee -a ${LOG_FILE}
    fi

    echo "$(date '+%d-%m-%Y %H:%M:%S') ...... OK" | tee -a ${LOG_FILE}

    sleep 2
    apt clean

    ## Send message if stub directory exists:
    if [[ -d '/etc/zentyal/stubs/' ]]; then
        echo "$(date '+%d-%m-%Y %H:%M:%S') ...... IMPORTANT: You might have persistant stubs, ensure you have the latest changes" | tee -a ${LOG_FILE}
    fi

    echo "$(date '+%d-%m-%Y %H:%M:%S') ... OK" | tee -a ${LOG_FILE}
}

function finishUpgrade
{
    sleep 2
    pkill -f upgrade-log-server
    touch $UPGRADE_FILE
    for log in /var/log/zentyal/zentyal.log /var/log/syslog /var/log/dpkg.log; do
        echo "## Update finished" >> ${log}
    done
}

####
## Calls
####

if [[ -f ${LOG_FILE} ]]; then
    rm -f ${LOG_FILE}
fi
touch ${LOG_FILE}

# Get the list of packages to be upgraded and hold them during the upgrade process to avoid issues with dependencies
PKG=$(dpkg -l | egrep '^ii.*(zenbuntu|zentyal|firefox)' | awk '{print $2}')

echo "$(date '+%d-%m-%Y %H:%M:%S') Preparing your system for the upgrade" | tee -a ${LOG_FILE}
prepareUpgrade
echo "$(date '+%d-%m-%Y %H:%M:%S') OK" | tee -a ${LOG_FILE}

echo "$(date '+%d-%m-%Y %H:%M:%S') Upgrading Ubuntu from ${CURCODE} to ${DSTCODE}" | tee -a ${LOG_FILE}
if [[ $(lsb_release -cs) != "${DSTCODE}" ]]; then
    preUbuntuUpgrade
    upgradeUbuntu
    postUbuntuUpgrade
    echo "$(date '+%d-%m-%Y %H:%M:%S') OK" | tee -a ${LOG_FILE}
else
    echo "$(date '+%d-%m-%Y %H:%M:%S') Ubuntu version is up to date...skkiping" | tee -a ${LOG_FILE}
fi

echo "$(date '+%d-%m-%Y %H:%M:%S') Upgrading Zentyal from ${CURRV} to ${DESTV}" | tee -a ${LOG_FILE}
preZentyalUpgrade
upgradeZentyal
postZentyalUpgrade
echo "$(date '+%d-%m-%Y %H:%M:%S') OK" | tee -a ${LOG_FILE}

echo "$(date '+%d-%m-%Y %H:%M:%S') Finishing the upgrade" | tee -a ${LOG_FILE}
finishUpgrade
