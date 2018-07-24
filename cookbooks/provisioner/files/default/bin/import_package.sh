#!/bin/bash

###
### Build scripts pulled from the Fuduntu EL Repo
###
### https://github.com/andrewwyatt/fuduntu-el
###
### Install: mock createrepo expect rpm-build
###
### Create a new key with gpg --gen-key and then create a .rpmmacro
###
### Builder should be in the mock group, the packages group, and have unrestricted nopasswd sudo
### Access to this machine should be restricted.
###
### sudo mkdir /data/mock /store -p
###

###
### **********  WARNING  WARNING  WARNING  WARNING  WARNING  WARNING  **********
###
### THIS IS A CHEF MANAGED SERVICE!  CHANGES MADE TO THIS FILE WILL NOT PERSIST!
### IF THIS FILE IS CHANGED, CHEF WILL REVERT IT AND RESTART THE APPLICABLE
### SERVICE!  YOU WILL BE HELD RESPONSIBLE FOR ANY OUTAGE THAT MAY OCCUR!
###
### **********  WARNING  WARNING  WARNING  WARNING  WARNING  WARNING  **********
###

source ${HOME}/etc/builder.conf

function notify() {
  if [ ${SLACK_ENABLED} ]
  then
    curl -X POST --data-urlencode "payload={\"channel\": \"${SLACK_CHANNEL}\", \"username\": \"${SLACK_USER}\", \"text\": \"$(hostname -f): $1\", \"icon_emoji\": \"${SLACK_EMOJI}\"}" "https://hooks.slack.com/services/${SLACK_API_PATH}" >/dev/null 2>&1
  fi
  echo $1
}

if [ ! -e "${1}" ] || [ "${1}" == "" ]
then
  echo "Please pass a full path to your package as the only argument."
  exit 1
fi

if [ "${2}" == "" ]
then
  REPOSITORY="UNSTABLE"
else
  REPOSITORY="${2}"
fi

$DEBUG && echo "BUILD: Using repository ${REPOSITORY}"
PACKAGE=${1}
PKGNAME=$(echo ${PACKAGE} | sed -s -e "s#^/.*/##")
notify "Adding package ${PKGNAME} to ${REPOSITORY}"

if [ -e "${BASEREPOPATH}/.importlock" ]
then
  $DEBUG && echo "IMPORT: Locked, exiting."
  exit 1
fi

if [ ! -d "${BASEREPOPATH}/${REPOSITORY}" ]
then
  mkdir -p "${BASEREPOPATH}/${REPOSITORY}"
fi

$DEBUG && echo "IMPORT: Setting package permissions [${PACKAGE}]"
sudo chown ${OWNER}:${GROUP} ${PACKAGE}
sudo chmod ${MODE} ${PACKAGE}

$DEBUG && echo "IMPORT: Signing package [${PACKAGE}]"
notify "Signing ${PKGNAME}"
cat >/tmp/sign_them.exp 2>/dev/null <<EOF
#!/usr/bin/expect -f

set password [lindex "\$argv" 0]
set package [lindex "\$argv" 1]

set timeout 20
set debug 1

spawn rpm --resign \$package
expect -exact "Enter pass phrase: "
send -- "\$password\r"
expect eof
EOF
expect -f /tmp/sign_them.exp "${SIGNKEY}" "${PACKAGE}">/dev/null
rm -f /tmp/sign_them.exp

while true
do
  if [ ! -e "${BASEREPOPATH}/.synclock" ]
  then
    $DEBUG && echo "IMPORT: Moving built package(s) and updating repo metadata."
    touch ${HOME}/.buildlock
    if [ ! -d "${BASEREPOPATH}/${REPOSITORY}/RPMS" ]
    then
      mkdir -p "${BASEREPOPATH}/${REPOSITORY}/RPMS"
    fi
    notify "Moving ${PACKAGE} to ${REPOSITORY}/RPMS"
    mv -vf  ${PACKAGE} ${BASEREPOPATH}/${REPOSITORY}/RPMS
    cd ${BASEREPOPATH}/${REPOSITORY}/RPMS
    createrepo --update .
    if [ ! -d "${BASEREPOPATH}/${REPOSITORY}/SRPMS" ]
    then
      mkdir -p "${BASEREPOPATH}/${REPOSITORY}/SRPMS"
    fi
    cd ${BASEREPOPATH}/${REPOSITORY}/SRPMS
    sudo chown -R ${OWNER}:${GROUP} ${BASEREPOPATH}/${REPOSITORY}
    sudo chmod -R ${MODE} ${BASEREPOPATH}/${REPOSITORY}
    createrepo --update .
    rm -f ${HOME}/.buildlock
    break
  fi
  $DEBUG && echo "IMPORT: Locked, sleeping"
  sleep 5
done
