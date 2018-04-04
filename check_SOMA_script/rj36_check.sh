#!/bin/sh
#rj_check
#date:20180202
script_ver=3.6

check_disk(){
	disk_check=$(mount | grep -c /mediacenter)
    disk_usage=$(df -h|grep mediacenter|awk '{print $5}')
	disk_ro_check=$(mount | grep /mediacenter|awk -F, '{print $1}'|grep -c rw)
	if [ ${disk_check} -eq 0 ];then
		disk_status="umount" 
	elif [ ${disk_ro_check} -eq 0 ];then
		disk_status="readonly"	
	else
		disk_status="OK"
        check_movie
	fi
}

check_nginx(){
    nginx_ver=$(awk -F':' '$1~/version/{print $2}' /etc/nginx/conf.d/airmedia_conf.conf)
	if [ $(ps -w|grep -v grep|grep -c nginx) -lt 1 ];then
		/usr/sbin/nginx
		if [ $? -ne 0 ];then
			nginx_status="failed"
		else
			nginx_status="OK"
		fi
	else
		nginx_status="OK"
	fi
}

check_flash(){
    flash_usage=$(df -h|grep  rootfs|awk '{print $5}')
    sleep 2
}

root_ro_chk(){
	root_ro_check=$(mount | grep rootfs|awk -F'(' '{print $2}'|grep -c rw)
	if [ ${root_ro_check} -eq 0 ];then
		root_status="readonly"
	else
		root_status="OK"
	fi 
}

check_dma(){
    dma_ver=$(cat /mediacenter/wangfan/version)
	if [ $(ps -w|grep -v grep|grep -c ihb620) -lt 1 ];then
		ps -w|grep hb_daemon|grep -v grep|awk '{print $1}'|xargs kill -9
		/bin/bash /mediacenter/wangfan/hb_daemon.sh &
		sleep 60
		if [ $(ps -w|grep -v grep|grep -c ihb620) -lt 1 ];then 
			dma_status="failed"
		else		
			dma_status_check
		fi
	else		
		dma_status_check
	fi
}

dma_status_check(){
	dma_code=$(curl --max-time 3 -w %{http_code} -s -o /dev/null localhost:16621/api/getinfo)
	if [ ! ${dma_code} ];then
		dma_status="failed"
	else
		dma_status="ok"
	fi
}

check_script(){
	if [ ${dev_md5} != ${soma_md5} ];then
		curl -s --connect-timeout 3 -o /rg_sbin/check.sh.tmp "http://api.amol.com.cn/soma/api/ops/script/get/ruijie/check.sh" 2>&1
		tmp_md5=$(md5sum /rg_sbin/check.sh.tmp |awk '{print $1}')
		
		if [ ${tmp_md5} == ${soma_md5} ];then
			mv /rg_sbin/check.sh.tmp /rg_sbin/check.sh
			chmod 777 /rg_sbin/check.sh			
			/bin/sh /rg_sbin/check.sh &
			exit
		fi
	fi
}

check_movie(){
    por_dir="/mediacenter/airmedia/portal"
    movie_list_dir=${por_dir}/data/appvideo/movie_size_list
    find ${por_dir}/cms/videos/ -type f -name *.mp4|xargs ls -l|sed 's/[[:space:]]*/\//g'|awk -F'/' 'BEGIN{ORS="";print "{"}{print "\""$NF"\":"$6","}END{print "}"}'|sed 's/,}/}/g' >${movie_list_dir}
}

upload_info(){
	dev_md5=$(md5sum /rg_sbin/check.sh |awk '{print $1}')	
	soma_md5=$(curl -s -I http://api.amol.com.cn/soma/api/ops/script/get/ruijie/check.sh|awk '$1~/Md5/{print $2}')
	sn=$(uci show sysinfo|grep serial_num|awk -F'=' '{print $2}')
	check_script
		echo "{\"script_ver\":\"${script_ver}\",\
        \"user\":\"RD:ops\",\
        \"time\":\"$(date +'%Y-%m-%dT%H:%M:%S%z')\",\
        \"deviceSN\":\"${sn}\",\
        \"items\":[{\
        \"item\":\"disk\",\"status\":\"${disk_status}\",\"disk_usage\":\"${disk_usage}\"},\
        {\"item\":\"dma\",\"status\":\"${dma_status}\",\"dma_ver\":\"${dma_ver}\"},
        {\"item\":\"nginx\",\"status\":\"${nginx_status}\",\"nginx_ver\":\"${nginx_ver}\"},\
        {\"item\":\"root\",\"status\":\"${root_status}\"},\
        {\"item\":\"flash\",\"status\":\"${flash_usage}\"},\
        {\"item\":\"uptime\",\"status\":\"$(uptime)\"}\
        ]}" >/tmp/check.log
	curl -d @/tmp/check.log http://api.amol.com.cn/soma/api/r/ops  
}

check_proc() {
	echo "Version: " ${script_ver} > /tmp/proc
	echo "DeviceSN: " $(uci show sysinfo|awk -F'=' '$1~/serial_num/{print $2}') >> /tmp/proc
	echo "Time: " $(date +'%Y-%m-%dT%H:%M:%S%z') >> /tmp/proc
	echo "------PROC" >> /tmp/proc
	find /proc/ -name "exe" 2> /dev/null | grep -v "/task/" | xargs  ls -la 2>/dev/null | awk '{print $11}' | sort -u | xargs ls -lae >> /tmp/proc
	curl -T /tmp/proc http://api.amol.com.cn/soma/api/r/proc
}

start_check(){
	check_disk
	check_nginx
    check_flash
    root_ro_chk
	check_dma
	upload_info
	check_proc
}
start_check