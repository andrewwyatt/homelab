#!/bin/bash

###
###
### Build scripts pulled from the Fuduntu EL Repo
###
### https://github.com/andrewwyatt/fuduntu-el
###
### Watch /home/builder/uploads for a package, and spawn builder if one or more
### are found.
###
### Add to builder's cron to run every 60 seconds...
### Make sure builder has access to cron in Chef
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
    /bin/notify "${SLACK_USER}" "${SLACK_CHANNEL}" "${SLACK_CHANNEL}" "${SLACK_API_PATH}" "$1"
  fi
  echo $1
}

if [ -e "${UPLOADPATH}/.watchlock" ]
then
  $DEBUG && echo "WATCH: Locked, exiting."
  exit 1
fi

for repos in ${REPOSITORIES[@]}
do

  REPOSITORY=${repos}

  if [ ! -d "${UPLOADPATH}/${REPOSITORY}" ]
  then
    mkdir -p ${UPLOADPATH}/${REPOSITORY}
  fi

  sudo chown -R ${OWNER}:${GROUP} ${UPLOADPATH}/${REPOSITORY}
  sudo chmod -R ${MODE} ${UPLOADPATH}/${REPOSITORY}

  PACKAGECOUNT=$(find ${UPLOADPATH}/${REPOSITORY} -name \*rpm 2>/dev/null | wc -l)
  if (( "$PACKAGECOUNT" > "0" ))
  then
    ### We want to lock on the main upload path so we don't spawn multiple workers.
    ### This should be a serial process, until a future update alters how mock build works
    touch ${UPLOADPATH}/.watchlock
    $DEBUG && echo "WATCH: Package count greater than zero [${PACKAGECOUNT}]"
    PACKAGES=($(find ${UPLOADPATH}/${REPOSITORY} -name \*rpm 2>/dev/null))
    for BPACKAGE in "${PACKAGES[@]}"
    do
      PKGNAME=$(echo ${BPACKAGE} | sed -s -e "s#^/.*/##")
      if [[ "$BPACKAGE" =~ x86_64  || "$BPACKAGE" =~ i[3-6]86.rpm || "$BPACKAGE" =~ noarch || "$BPACKAGE" =~ x64 ]]
      then
        $DEBUG && echo "WATCH: Found binary package: [${BPACKAGE}]"
        notify "Someone uploaded a new binary package, ${PKGNAME}."
        $HOME/bin/import_package.sh ${BPACKAGE} ${REPOSITORY}
        if [ "$?" = 0 ]
        then
          notify "Import of ${PKGNAME} successful."
          $DEBUG && echo "WATCH: Successful imported, deleting [${BPACKAGE}]"
          rm -f ${BPACKAGE}
        fi
      elif [[ "$BPACKAGE" =~ src ]]
      then
        notify "Someone uploaded a new source package, ${PKGNAME}"
        $DEBUG && echo "WATCH: Found package: [${BPACKAGE}]"
        $HOME/bin/build_package.sh ${BPACKAGE} ${REPOSITORY}
        if [ "$?" = 0 ]
        then
          notify "${PKGNAME} was built successfully."
          $DEBUG && echo "WATCH: Successful build, deleting [${BPACKAGE}]"
          rm -f ${BPACKAGE}
        fi
      fi
    done
    rm -f ${UPLOADPATH}/.watchlock
  else
    $DEBUG && echo "WATCH: Package Count returned [${PACKAGECOUNT}], nothing to do."
  fi
done
