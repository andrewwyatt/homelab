#!/bin/bash

###
### Watches a pool of repositories and refreshes the repository metadata when packages are added or removed
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

for repo in ${REPOSITORIES[@]}
do
  cd ${BASEREPOPATH}
  REPOSITORY=${repo}
  for RTYPE in RPMS SRPMS
  do
    if [ ! -e "${HOME}/.buildlock" ]
    then
      $DEBUG && echo "DEBUG: Locking repository to update metadata"
      touch ${HOME}/.buildlock
      $DEBUG && echo "DEBUG: READING EXISTING HASH (${BASEREPOPATH}/.${REPOSITORY}.${RTYPE}.SHA256)"
      HASH=$(cat ${BASEREPOPATH}/.${REPOSITORY}.${RTYPE}.SHA256 2>/dev/null)
      $DEBUG && echo "DEBUG: HASH VALUE = (${HASH})"
      $DEBUG && echo "DEBUG: CALCULATING CHECKSUM OF (${BASEREPOPATH}/${REPOSITORY}/${RTYPE})"
      SUM=$(find ${BASEREPOPATH}/${REPOSITORY}/${RTYPE} -not -path "*/repodata/*" -type f -printf '%T@ %p\n' 2>/dev/null | sha256sum | awk '{print $1}')
      $DEBUG && echo "DEBUG: SUM VALUE = (${SUM})"
      if [[ "${HASH}" != "${SUM}" ]]
      then
        notify "Hash mismatch at ${REPOSITORY}/${RTYPE}, updating repository metadata."
        $DEBUG && echo "DEBUG: Updating repository metadata for (${BASEREPOPATH}/${REPOSITORY}/${RTYPE})"
        cd ${BASEREPOPATH}/${REPOSITORY}/${RTYPE}
        createrepo --update . >/dev/null 2>&1
        $DEBUG && echo "DEBUG: Cleaning up repository and package permissions (${OWNER}:${GROUP}:${MODE})"
        sudo chown -R ${OWNER}:${GROUP} ${BASEREPOPATH}/${REPOSITORY}/${RTYPE} >/dev/null 2>&1
        sudo chmod -R ${MODE} ${BASEREPOPATH}/${REPOSITORY}/${RTYPE} >/dev/null 2>&1
        $DEBUG && echo "DEBUG: Saving checksum"
        echo ${SUM} >${BASEREPOPATH}/.${REPOSITORY}.${RTYPE}.SHA256
        sudo chown -R ${OWNER}:${GROUP} ${BASEREPOPATH}/.${REPOSITORY}.${RTYPE}.SHA256
        sudo chmod -R ${MODE} ${BASEREPOPATH}/.${REPOSITORY}.${RTYPE}.SHA256
      else
        $DEBUG && echo "DEBUG: Repository data match for (${BASEREPOPATH}/${REPOSITORY}/${RTYPE}), nothing to do"
      fi
      $DEBUG && echo "DEBUG: Unlocking repository"
      rm ${HOME}/.buildlock
    else
      $DEBUG && echo "DEBUG: Repository locked, exiting."
    fi
  done
done
