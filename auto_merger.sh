#! /bin/sh

#

# Your script full path
SCRIPT=$(readlink -f "$0")

# base dir path
BASE_DIR=$(dirname "$SCRIPT")

# email address to send the conflict notification to
RECIPIENT="wei.liu@zuora.com"

function printUsage
{
    cat << __Usage

Automatic merge tool.

Usage: $0 -m wei.liu@zuora.com

Options:
    -m: email address, the recipient when conflicts are detected.


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
        0 */4 * * * ~/data_access/auto_merger.sh -m wei.liu@zuora.com 2>&1 > ~/data_access/merge.log        

Enjoy!!!

__Usage
}

# parse command parameters.
while getopts "m:" opt; do
    case $opt in
        m)
            RECIPIENT=$OPTARG
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
    local c1=`svn status | grep 'C ' | cut -b 1`
    if [ ${#c1[@]} -gt 0 ]; then
        for c in $c1 
        do  
            if [ "$c" != "" ]; then
                echo 'content conflict found'
                conflict=1
                return
            fi  
        done
    fi

    local c7=`svn status | grep 'C ' | cut -b 7`
    if [ ${#c7[@]} -gt 0 ]; then
        for c in $c7 
        do  
            if [ "$c" != "" ]; then
                echo 'tree conflict found'
                conflict=7
                return
            fi  
        done
    fi

    local c2=`svn status | grep 'C ' | cut -b 2`
    if [ ${#c2[@]} -gt 0 ]; then
        for c in $c2 
        do  
            if [ "$c" != "" ]; then
                echo 'directory conflict found'
                conflict=2
                return
            fi  
        done
    fi
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
  svn merge --accept postpone ${MAIN_BASE_BRANCH}/ZuoraPanda3 ${BASE_DIR}/$DIR_ > ${BASE_DIR}/last_merge.log
  
  # after merge, check if there are conflicts
  detectConflict
  
  # for content and tree conflicts, you will be notified.
  if [ $conflict -eq 1 -o $conflict -eq 7 ]; then
    echo '${flag_}' | mail -s 'auto-merge report: there is a conflict' ${RECIPIENT}
    exit
  elif [ $conflict -eq 2 ]; then
    # resolve directory conflict
    svn resolve -R --accept working .
  fi

  # commit the change if everything is good.
  svn commit -m 'merge updagte from main automatically' --force-log ${BASE_DIR}/$DIR_
  
done

