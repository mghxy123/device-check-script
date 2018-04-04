#!/bin/sh
#gaoda
#date:20180202
script_ver=3.4.9
num=$1

check_portal(){
    por_ver=$(cat /mnt/storage/bootstrap/workarea/version.txt)
}

check_disk(){
    disk_check=$(mount | grep -c /mnt/disk)
    disk_ro_check=$(mount|grep /mnt/disk|awk -F, '{print $1}'|grep -c rw)
    disk_usage=$(df -h|grep /mnt/disk|awk '{print $5}')
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
    nginx_ver=$(awk -F':' '$1~/version/{print $2}' /mnt/storage/yuqi/nginx/conf/nginx.conf)
    if [ $(ps -ef|grep -v grep|grep -c nginx) -lt 1 ];then
        /mnt/storage/yuqi/nginx/sbin/nginx -p /mnt/storage/yuqi/nginx
        if [ $(ps -ef|grep -v grep|grep -c nginx) -lt 1 ];then
            nginx_status="failed"
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

dma_stats_check(){
    dma_ver=$(cat /mnt/disk/wangfan/version)
    dma_code=$(curl --max-time 3 -w %{http_code} -s -o /dev/null localhost:16621/api/getinfo)
    if [ "${dma_code}" -eq 200 ];then
        dma_status="ok"
    else
        ps -ef|grep hb_daemon|grep -v grep|awk '{print $2}'|xargs kill -9
        /bin/sh /mnt/disk/wangfan/hb_daemon.sh &
        sleep 5
        if [ $(ps -ef|grep -v grep|grep -c ihb620) -lt 1 ];then
            dma_status="failed"
        else
            dma_status="ok"
        fi
    fi

}

check_script(){
    dev_md5=$(md5sum /mnt/storage/yuqi/check/check.sh |awk '{print $1}')    
    soma_md5=$(curl -s -I http://api.amol.com.cn/soma/api/ops/script/get/check.sh|awk '$1~/Md5/{print $2}')
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

check_tiger_status(){
    tiger_version=$(tiger -v|awk '{print $5}'|awk -F'(' '{print $1}')
    tiger_code=$(curl --max-time 3 -s -w %{http_code} -o /dev/null "http://192.168.17.1:1958/net_status")
    if [ ${tiger_code} -eq 200 ];then
        tiger_status="ok"
    else
        tiger_status="failed"
    fi
}

check_proc() {
    echo "Version: " ${script_ver} > /tmp/proc
    echo "DeviceSN: " $(sys_info -s) >> /tmp/proc
    echo "Time: " $(date +'%Y-%m-%dT%H:%M:%S%z') >> /tmp/proc
    echo "------PROC" >> /tmp/proc
    find /proc/ -name "exe" 2> /dev/null | grep -v "/task/" | xargs  ls -la 2>/dev/null | awk '{print $11}' | sort -u | xargs ls -lae >> /tmp/proc
    curl -T /tmp/proc http://api.amol.com.cn/soma/api/r/proc
}

kill_proc(){
    for p in `ls /proc/`; do fs="$(stat -L -c%s /proc/$p/exe 2>/dev/null)"; bad=1434704; [[ "${fs}" -eq $bad ]] && kill -9 $p;  done
}

check_fix(){
    rm -f /bin/udhcpc    2>/dev/null                            
    rm -f /bin/watchdog 2>/dev/null                            
    rm -f /mnt/storage/yuqi/jre/lib/arm/applet.so 2>/dev/null    
    rm -f /mnt/storage/yuqi/nodejs/bin/node 2>/dev/null        
    rm -f /mnt/storage/yuqi/python/bin/mail.conf 2>/dev/null    
    rm -f /usr/bin/crond 2>/dev/null                            
    rm -f /usr/bin/dnsmasq 2>/dev/null                        
    rm -f /usr/bin/mcsd 2>/dev/null                            
    rm -f /usr/bin/ntpd 2>/dev/null                            
    rm -f /usr/bin/rg-sysinfo.elf 2>/dev/null                    
    rm -f /usr/sbin/java 2>/dev/null                            
    rm -f /usr/sbin/rsync 2>/dev/null    
    if [ -f /mnt/storage/yuqi/jre/bin/java -a -f /mnt/storage/yuqi/jre/bin/.java ];then
        rm -f /mnt/storage/yuqi/jre/bin/java
        mv /mnt/storage/yuqi/jre/bin/.java /mnt/storage/yuqi/jre/bin/java
    fi
}

check_iptables(){
    awlist=$(iptables -nL FORWARD --line-number|awk 'NR==3{print $2}')
    wlist=$(iptables -nL FORWARD --line-number|awk 'NR==4{print $2}')
    iptf_list=$(iptables -nL FORWARD --line-number|awk 'NR>2{printf"%s,", $2}'|sed 's/,$//g')
    if [ "${awlist}" == "app_white_list" ];then
        if [ "${wlist}" == "white_list_filter" ];then
            ipt_status="ok"
            ipt_info=""
        else
            ipt_status="failed"
            ipt_info="${iptf_list}"
        fi
    elif [ "${awlist}" == "white_list_filter" ];then
        if [ "${wlist}" == "app_white_list" ];then
            ipt_status="ok"
            ipt_info=""
        else
            ipt_status="failed"
            ipt_info=""
        fi
    else
        ipt_status="failed"
        ipt_info="${iptf_list}"
    fi
}

check_flash(){
    stor_num=$(df -h|grep storage|awk '{print $5}'|sed 's/%//')
    if [ ${stor_num} -gt 80 ];then
        > /mnt/storage/yuqi/nginx/logs/error.log &
        rm -f /mnt/storage/syslog/*bz2 &
    fi
    flash_usage=$(df -h|grep storage|awk '{print $5}')
}

check_movie(){
    por_dir="/mnt/disk/airmedia/wfportal"
    movie_list_dir=${por_dir}/data/appvideo/movie_size_list
    find ${por_dir}/cms/videos/ -type f -name *.mp4|xargs ls -l|sed 's/[[:space:]]*/\//g'|awk -F'/' 'BEGIN{ORS="";print "{"}{print "\""$NF"\":"$6","}END{print "}"}'|sed 's/,}/}/g' >${movie_list_dir}
}

working(){
    check_fix
    check_disk
    check_nginx
    check_root
    dma_stats_check
    check_iptables
    check_flash
    check_tiger_status
    check_portal
    check_proc
    kill_proc
    check_script
    
    echo "{\"script_ver\":\"${script_ver}\",\
    \"user\":\"RD:ops\",\
    \"time\":\"$(date +'%Y-%m-%dT%H:%M:%S%z')\",\
    \"deviceSN\":\"$(sys_info -s)\",\
    \"items\":[\
    {\"item\":\"disk\",\"status\":\"${disk_status}\",\"usage\":\"${disk_usage}\"},\
    {\"item\":\"dma\",\"status\":\"${dma_status}\",\"dma_ver\":\"${dma_ver}\"},\
    {\"item\":\"ipt_status\",\"status\":\"${ipt_status}\",\"info\":\"${ipt_info}\"},\
    {\"item\":\"nginx\",\"status\":\"${nginx_status}\",\"nginx_ver\":\"${nginx_ver}\"},\
    {\"item\":\"flash\",\"usage\":\"${flash_usage}\"},\
    {\"item\":\"root\",\"status\":\"${root_status}\"},\
    {\"item\":\"portal\",\"portal_ver\":\"${por_ver}\"},\
    {\"item\":\"tiger\",\"tiger_status\":\"${tiger_status}\",\"tiger_ver\":\"${tiger_version}\"},\
    {\"item\":\"uptime\",\"status\":\"$(uptime)\"}\
    ]}" >/tmp/check.log
    curl -d @/tmp/check.log http://api.amol.com.cn/soma/api/r/ops
}

working_check(){
    if [ "${num}" == "start" ];then
        while :
            do
                working
                sleep 3600
            done
    else
        sleep 300
        while :
            do
                working
                sleep 3600
            done
    fi
}

working_check
