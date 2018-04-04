#!/bin/sh
mount_dir=$(df -h|grep mnt|awk '{print $6}')
git_dir=${mount_dir}/tmp/git_file
echo $(date +'[%Y-%m-%d %H:%M:%S]') > /mnt/disk/update_debug.log
sh -x ${mount_dir}/html/rj_update.sh >> /mnt/disk/update_debug.log 2>&1
#sleep 5
update_script(){
	if [ -f ${git_dir}/script/rj_update.sh.1 ];then
       mv ${git_dir}/script/rj_update.sh.1 ${mount_dir}/html/rj_update.sh
	fi
}	
update_script