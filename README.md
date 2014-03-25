SVN Auto Merger
=============

A tool to help you automatically merge between SVN branches.

The Purpose
----------
Given you are working on a project which has two physical code projects, if you are working on a big new feature, you don't want work directly on the `trunk` since the big new feature can not be finished in one release, the best way to do so is to branch out your own branches, and work on them.

Note that there are more people working on the `trunk`, so you need merge their changes to your branches and know what's been changed, the merge should happen at least on a daily basis.

This tool is to help you do the merge automatically.

Pre-requisites
------------
1. subversion
2. mail (to send email notification if there is conflicts)
3. crontab (to trigger the job periodically)


How to Use
-----------
The philosophy is 'convention over configuration', so you need to create fold structure as below.

1. create a folder,  say `your_path`, as base dir.
2. check out your own branches of `framework` and `webapp` as subfolders (make sure your svn credential is stored)
3. put this script under base dir `your_path`, now, the fold structure would be:

```
    ./your_path
        |___framework/
        |___webapp/
        |___auto_merger.sh
```
4. add a cron job to trigger the script periodically, for example: 

    crontab -e
    
In the crontab editor, type `0 */4 * * * <path_to_your_base_dir>/auto_merger.sh -m wei.liu@zuora.com 2>&1 > <path_to_your_base_dir>/merge.log` 

