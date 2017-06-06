#!/bin/sh

script_ver=3.1
set_null(){
	tiger_version=
	disk_check=
	disk_ro_check=
	disk_status= 
	hb_stats=
	nginx_status=
	root_status=
	nginx_size_percent=
	check_return=
	size=
	soma_md5=
	dev_md5=
	tmp_md5=
}

check_disk(){
	disk_check=$(mount | grep -c /mnt/disk)
	disk_ro_check=$(mount | grep /mnt/disk|awk -F, '{print $1}'|grep -c rw)
	if [ ${disk_check} -eq 0 ];then
		disk_status="umount" 
	elif [ ${disk_ro_check} -eq 0 ];then
		disk_status="readonly"	
	else
		disk_status="OK"
	fi
}

check_nginx(){
	if [ $(ps -ef|grep -v grep|grep -c nginx) -lt 1 ];then
		/mnt/storage/yuqi/nginx/sbin/nginx -p /mnt/storage/yuqi/nginx
		if [ $? -ne 0 ];then
			nginx_size_percent=$(df -h|grep storage|awk '{print $5}')
			nginx_status="nginx used ${nginx_size_percent}"
		else
			nginx_status="OK"
		fi
	else
		nginx_status="OK"
	fi
}

check_root(){
	root_ro_check=$(mount | grep /dev/root|awk -F, '{print $1}'|grep -c rw)
	if [ ${root_ro_check} -eq 0 ];then
		root_status="readonly"
	else
		root_status="OK"
	fi 
}

check_hb(){
	if [ $(ps -ef|grep -v grep|grep -c ihb620) -ne 1 ];then
		/bin/sh /mnt/disk/wangfan/hb_daemon.sh &
		sleep 60
		if [ $(ps -ef|grep -v grep|grep -c ihb620) -ne 1 ];then
			hb_stats="failed"
		else		
			hb_stats=$(curl -s --connect-timeout 3 localhost:16621/api/getinfo 2>&1|awk -F'"' '{print $4}')
		fi
	else		
		hb_stats=$(curl -s --connect-timeout 3 localhost:16621/api/getinfo 2>&1|awk -F'"' '{print $4}')
	fi
}

check_script(){
	if [ ${dev_md5} != ${soma_md5} ];then
		curl -s --connect-timeout 3 -o /mnt/storage/yuqi/check/check.sh.tmp "http://api.amol.com.cn/soma/api/ops/script/get/check.sh"
		tmp_md5=$(md5sum /mnt/storage/yuqi/check/check.sh.tmp |awk '{print $1}')
		
		if [ ${tmp_md5} == ${soma_md5} ];then
			mv /mnt/storage/yuqi/check/check.sh.tmp /mnt/storage/yuqi/check/check.sh
			/bin/sh /mnt/storage/yuqi/check/check.sh &
			exit
		fi
	fi	
}

	sleep 300
while :
	do
	set_null
	check_disk
	check_nginx
	check_root
	check_hb
		
	dev_md5=$(md5sum /mnt/storage/yuqi/check/check.sh |awk '{print $1}')	
	soma_md5=$(curl -s -I http://api.amol.com.cn/soma/api/ops/script/get/check.sh|awk '$1~/Md5/{print $2}')
	tiger_version=$(tiger -v|awk '{print $5}'|awk -F'(' '{print $1}')

	check_script
	
	echo {\"script_ver\":\"${script_ver}\",\"user\":\"RD:ops\",\"time\":\"$(date +'%Y-%m-%dT%H:%M:%S%z')\",\"deviceSN\":\"$(sys_info -s)\",\"items\":[{\"item\":\"disk\",\"status\":\"${disk_status}\"},{\"item\":\"heartbeat\",\"status\":\"${hb_stats}\"},{\"item\":\"nginx\",\"status\":\"${nginx_status}\"},{\"item\":\"root\",\"status\":\"${root_status}\"},{\"item\":\"tiger\",\"status\":\"${tiger_version}\"},{\"item\":\"uptime\",\"status\":\"$(uptime)\"}]} >/tmp/check.log

	curl -d @/tmp/check.log http://api.amol.com.cn/soma/api/r/ops  	
	sleep 3600
done
