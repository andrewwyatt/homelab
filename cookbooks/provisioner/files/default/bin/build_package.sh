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
    /bin/notify "${SLACK_CHANNEL}" "${SLACK_CHANNEL}" "${SLACK_API_PATH}" "$1"
  fi
  echo $1
}

if [ ! "${SIGNKEY}" ]
then
  echo "Please export the package signing key before running."
  exit 1
fi

if [ ! -e "${1}" ] || [ "${1}" == "" ]
then
  echo "Please pass a full path to your package as the first argument."
  exit 1
fi

if [ "${2}" == "" ]
then
  REPOSITORY="UNSTABLE"
else
  REPOSITORY="${2}"
fi

$DEBUG && echo "BUILD: Using repository ${REPOSITORY}"

if [ -e "${HOME}/.buildlock" ]
then
  $DEBUG && echo "BUILD: Locked, exiting."
  exit 1
fi

if [ ! -d "${BASEREPOPATH}/${REPOSITORY}" ]
then
  mkdir -p "${BASEREPOPATH}/${REPOSITORY}"
fi

### Flush the result directory...
$DEBUG && echo "BUILD: Removing ${RESULTPATH}/*"
if [ ${RESULTPATH} ]
then
  rm -rf ${RESULTPATH}/* 2>/dev/null ||:
else
  echo "Define the reult path variable."
  exit 1
fi

PKGNAME=$(echo ${1} | sed -s -e "s#^/.*/##")
$DEBUG && echo "BUILD: Building package: ${1}"
notify "Using mock to build package ${PKGNAME}"
mock -r ${CONF}-${REPOSITORY} --resultdir=${RESULTPATH} --rebuild ${1}

if [ ! $? = 0 ]
then
  notify "The build of ${PKGNAME} has failed, please check the logs on $(hostname -f)"
  $DEBUG && echo "BUILD: Failed, moving package to [${FAILEDPATH}]"
  if [ ! -e "${FAILEDPATH}" ]
  then
    mkdir -p ${FAILEDPATH}
  fi
  mv ${1} ${FAILEDPATH}/${1}
  mv ${RESULTPATH}/build.log ${FAILEDPATH}/${1}.build.log
  exit 1
else
  notify "The build of ${PKGNAME} completed successfully."
fi

sudo chown -R ${OWNER}:${GROUP} ${RESULTPATH}
sudo chmod -R ${MODE} ${RESULTPATH}

### Don't need debug packages, when I do I build them locally.
$DEBUG && echo "BUILD: Removing debug packages"
rm -f  ${RESULTPATH}/*debug*rpm

### Assumes .rpmmacros is configured properly...
for PACKAGE in ${RESULTPATH}/*rpm
do
PKGNAME=$(echo ${PACKAGE} | sed -s -e "s#^/.*/##")
notify "Signing ${PKGNAME}"
$DEBUG && echo "BUILD: Signing package [${PACKAGE}]"
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
done

while true
do
  if [ ! -e "${BASEREPOPATH}/.synclock" ]
  then
    $DEBUG && echo "BUILD: Moving built package(s) and updating repo metadata."
    touch ${HOME}/.buildlock
    if [ ! -d "${BASEREPOPATH}/${REPOSITORY}/SRPMS" ]
    then
      mkdir -p "${BASEREPOPATH}/${REPOSITORY}/SRPMS"
    fi
    notify "Moving source packages to ${REPOSITORY}/SRPMS"
    mv -vf ${RESULTPATH}/*src.rpm ${BASEREPOPATH}/${REPOSITORY}/SRPMS
    if [ ! -d "${BASEREPOPATH}/${REPOSITORY}/RPMS" ]
    then
      mkdir -p "${BASEREPOPATH}/${REPOSITORY}/RPMS"
    fi
    notify "Moving binary packages to ${REPOSITORY}/RPMS"
    mv -vf  ${RESULTPATH}/*rpm ${BASEREPOPATH}/${REPOSITORY}/RPMS
    cd ${BASEREPOPATH}/${REPOSITORY}/RPMS
    createrepo --update .
    cd ${BASEREPOPATH}/${REPOSITORY}/SRPMS
    createrepo --update .
    sudo chown -R ${OWNER}:${GROUP} ${BASEREPOPATH}
    sudo chmod -R ${MODE} ${BASEREPOPATH}
    rm -f ${HOME}/.buildlock
    break
  fi
  $DEBUG && echo "BUILD: Locked, sleeping"
  sleep 5
done
