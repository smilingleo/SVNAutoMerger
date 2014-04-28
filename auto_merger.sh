#! /bin/sh

# Your script full path
SCRIPT=$(readlink -f "$0")

# base dir path
BASE_DIR=$(dirname "$SCRIPT")

# email address to send the conflict notification to
RECIPIENT="email@test.com"

# default main branch name
TRUNK="Main"

function printUsage
{
    cat << __Usage

Automatic merge tool.

Usage: $0 -m wei.liu@zuora.com -t Main

Options:
    -m: email address, the recipient when conflicts are detected.
    -t: trunk name, default to 'Main'


Before use this command, read the following how-to:

    How to use this script
    =======================
    1. create a folder,  say 'data_access', as base dir.
    2. check out your own branches of 'framework' and 'webapp' as subfolders (make sure your svn credential is stored)
    3. put this script under base dir ('data_access'), now, the fold structure would be:

      ./data_access
           |___framework/
           |___webapp/
           |___auto_merger.sh

    4. add a cron job to trigger the script periodically, for example: 
      > crontab -e
        0 */4 * * * ~/data_access/auto_merger.sh -m email@test.com 2>&1 > ~/data_access/merge.log        

Enjoy!!!

__Usage
}

# parse command parameters.
while getopts "m:t:" opt; do
    case $opt in
        m)
            RECIPIENT=$OPTARG
            ;;
        t)
            TRUNK=$OPTARG
            ;;
        \?)
            printUsage
            exit 1
            ;;
    esac
done

cd ${BASE_DIR}

# a flag of conflict type
# 1 -> content conflict
# 2 -> directory conflict
# 7 -> tree conflict
# this script can automatically solve type 2, and you need manually resolve the conflicts for 1 and 7.
conflict=0

function detectConflict()
{
    for items in `svn status | awk '{print $1}'`
    do
        flag1=`echo $items | cut -b 1`
        if [ $flag1 == 'C' ]; then
            echo 'content conflict found'
	    conflict=1
        fi

        flag2=`echo $items | cut -b 2`
        if [ $flag2 == 'C' ]; then
            echo 'directory conflict found'
	    conflict=2
	fi

        flag7=`echo $items | cut -b 7`
        if [ $flag7 == 'C' ]; then
            echo 'tree conflict found'
	    conflict=7
	fi
    done
}

# iterate all subfolders of base dir.
for _dir in $(ls -d */); do

  DIR_=`echo $_dir | sed 's/\///'`

  # remove log of last merge.
  if [ -e ${BASE_DIR}/last_merge.log ]; then
    rm ${BASE_DIR}/last_merge.log
  fi

  # update the working copy first.
  cd ${BASE_DIR}/$DIR_ && svn update

  # if `svn udpate` fails, try to recover it by 'clean up, revert, remove non-verson-controlled files then re-update the working copy'
  # this might happen when the previous svn merge process broke due to network issues, svn will lock the working items.
  if [ $? -gt 1 ]; then
    svn cleanup && svn revert -R . && svn status | grep '^?' | xargs rm -rf
    svn update 
  fi
  # get the branch name.  
  MAIN_BASE_BRANCH=`svn info | grep '^URL:' | cut -d ' ' -f 2 | awk -F/ '{print $NF}'`
  
  # merge `main` branch with your own branch into working copy
  svn merge --accept postpone ${MAIN_BASE_BRANCH}/$TRUNK ${BASE_DIR}/$DIR_ > ${BASE_DIR}/last_merge.log
  
  # after merge, check if there are conflicts
  detectConflict
  
  # for content and tree conflicts, you will be notified.
  if [ $conflict -eq 1 -o $conflict -eq 7 ]; then
    echo '${conflict}' | mail -s 'auto-merge report: there is a conflict' ${RECIPIENT}
    exit
  elif [ $conflict -eq 2 ]; then
    # resolve directory conflict
    svn resolve -R --accept working .
  fi

  # commit the change if everything is good.
  svn commit -m 'merge update from main automatically' --force-log ${BASE_DIR}/$DIR_
  
done

