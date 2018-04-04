#/bin/sh
#date:20170221
#author:huxianyong
#指定文件目录
#########################################################################################################
#说明：
#1、在设备版本高于U盘版本时，就会对除CMS之外的整个portal对比更新(之对比文件，不比较大小和时间，有就更新)
#2、在设备版本低于U盘版本时，U盘会对整个portal进行覆盖更新
#3、在设备上的资源文件会做增量更新，设备缺什么就更新什么
#4、设备在更新是会对整个data目录进行覆盖式更新，
#5、在设备版本低于U盘版本时，U盘会对整个portal进行覆盖更新(data会重复更新，但是问题不大)
#6、固件的命名方式为111为版本号，后面为-update.bin格式不能变
#7、wfportal必须是一个完整的目录
#8、U盘根目录下必须有，心跳目录，固件目录，list目录，wfportal目录，OBS目录，反向代理目录,html目录，7个目录
#9、增加了地方局的特色判断，给各个地方局拷贝不同的版本
#10、在此脚本之后的目录或文件，必须要存在2017，不然会被删除，此脚本只适用于2017年
#11、此脚本会删除nginx在wangfan目录下的所有未上传文件，还有删除
#12、此脚本不拷贝往返APP，也不做各个路局的版本判断
#13、APP新增了U盘版本展示，
#14、此脚本具有断电后,下次再次更新不会重复之前的动作的功能
#15、已加入王朝的最新java包,脚本已修改对于,电影,游戏,应用,综艺的动态列表生成
#########################################################################################################
mount_dir=$(df -h|grep mnt|awk '{print $6}')
dir_usb=${mount_dir}/wfportal
git_dir=${mount_dir}/tmp/git_file
dir_por=/mediacenter/airmedia/portal
dir_diff=/mnt/disk/difffile
usb_file_dir=${dir_usb}/cms
por_file_dir=${dir_por}/cms
LocalCheck=$(awk -F'"' 'NR==2{print $4}' ${dir_por}/config.json)
hb_ver_usb=$(cat ${mount_dir}/heartbeat/version)
hb_ver_por=$(cat /mediacenter/wangfan/version |tr -d "[a-z]")
usb_por_ver=$(awk -F '_' 'NR==2 {print $2}' ${dir_usb}/ver|tr -d '"'|awk -F '.' '{print $1$2$3}')
dev_por_ver=$(awk -F '_' 'NR==2 {print $2}' ${dir_por}/ver|tr -d '"'|awk -F '.' '{print $1$2$3}')
usb_sys_ver=$(uci show sysinfo|awk -F'(' '$2~/Release/{print $3}'|sed 's/)//')
dev_sys_ver=$(ls ${mount_dir}/rj_software/|awk -F'.' '{print $2}')

install_ssh(){
		cp -r ${mount_dir}/git/.ssh /root/
		chmod 700 /root/.ssh
		chmod 600 /root/.ssh/*
}

download_wfportal(){
	cd ${git_dir}
	if [ ! -d ${git_dir}/wfportal ];then
        mkdir -p ${git_dir}/wfportal && cd ${git_dir}
		git clone ssh://git@git.ihangmei.com:65022/huxianyong/wfportal.git
        if [ $? -eq 0 ];then
			cp -r ${git_dir}/wfportal/wfportal/* /mnt/usb/wfportal/
		else
			echo "git portal faled!!!"
		fi
	elif [ $(cd wfportal;git pull| grep -c changed) -gt 0 ];then		
        cp -r ${git_dir}/wfportal/wfportal/* /mnt/usb/wfportal/
    fi
}

download_script(){
	cd ${git_dir}
	if [ ! -d ${git_dir}/script ];then
        mkdir -p ${git_dir}/script && cd ${git_dir}
		git clone ssh://git@git.ihangmei.com:65022/huxianyong/script.git
        if [ $? -eq 0 ];then
			cp ${git_dir}/script/rj_update.sh ${git_dir}/script/rj_update.sh.1
		else
			echo "git portal faled!!!"
		fi
    elif [ $(cd script;git pull| grep -c changed) -gt 0 ];then
		cp ${git_dir}/script/rj_update.sh ${git_dir}/script/rj_update.sh.1
    fi
}

Chk_usb_por() {
	find ${git_dir}/wfportal/wfportal/ -type f|grep -v cms|xargs ls -l|awk '{print $5,$NF}'|sed "s#/mnt/usb/tmp/git_file/wfportal/wfportal/##g" |sort -k2,2 > ${dir_diff}/git_usb_por
	find ${mount_dir}/wfportal/ -type f|grep -v cms|xargs ls -l|awk '{print $5,$NF}'|sed "s#/mnt/usb/wfportal/##g"|sort -k2,2 > ${dir_diff}/usb_wfportal
	diff ${dir_diff}/git_usb_por ${dir_diff}/usb_wfportal |grep  ^-|sed '/---/d;s/^-//g' > ${dir_diff}/up_cp_por_file
	up_cp_por_sz=$(ls -l ${dir_diff}/up_cp_por_file|awk '{print $5}')
		if [ ${up_cp_por_sz} -gt 0 ];then
			for mkdri in $(cat ${dir_diff}/up_cp_por_file)
				do
					mkdir -p $(dirname ${git_dir}/${mkdri})
				done		
			for i in $(cat ${dir_diff}/up_cp_por_file)
				do 
					cp -rf ${git_dir}/wfportal/wfportal/$i ${mount_dir}/wfportal/$i
				done
		fi
}

Check_usb() {
if [ $? -ne 0 ]; then
    logOutput "error-1" "更新失败U盘异常退出更新"
	check_upload_log
    exit
fi
}
#输出日志
logOutput() {
    now=$(date +'[%Y-%m-%d %H:%M:%S]')
    echo "${now} [$1] $2" >> /mnt/disk/update_progress.log
}
file_check() {
logOutput "ok-2" "差异更新开始"
#创建文件夹
mkdir -p ${dir_diff}
mkdir -p /mnt/disk/airmedia
#检查设备上是否存在目录不存在直接拷贝目录
for file_dir in ${usb_file_dir}/*
	do
		logOutput "show" "正在更新${file_dir##*/}"
		find ${por_file_dir}/${file_dir##*/}/ -type f > /dev/null 2>&1
			if [ $? -eq 0 ];then
				find ${por_file_dir}/${file_dir##*/}/ -type f |awk '{ print $NF}'|xargs ls -l|awk '{print $5,$NF}'|sed "s#${dir_por}/##g" |sort -k2,2> ${dir_diff}/por_${file_dir##*/}
				find ${usb_file_dir}/${file_dir##*/}/ -type f |awk '{ print $NF}'|xargs ls -l|awk '{print $5,$NF}'|sed "s#${dir_usb}/##g"|sort -k2,2  > ${dir_diff}/usb_${file_dir##*/}
				diff ${dir_diff}/por_${file_dir##*/} ${dir_diff}/usb_${file_dir##*/} |grep ^-|sed '/---/d;s/^-//g'|awk '{print $2}' > ${dir_diff}/rm_por_file_${file_dir##*/}
				diff ${dir_diff}/por_${file_dir##*/} ${dir_diff}/usb_${file_dir##*/} |grep ^+|grep -v +++|awk '{print $2}' > ${dir_diff}/cp_por_file${file_dir##*/}
					cp_file_szie=$(ls -l ${dir_diff}/cp_por_file${file_dir##*/} |awk '{print $5}')
					rm_file_szie=$(ls -l ${dir_diff}/rm_por_file_${file_dir##*/} |awk '{print $5}')
					if [ ${rm_file_szie} -gt 0 ];then
						for i in $(cat ${dir_diff}/rm_por_file_${file_dir##*/}|grep -v 2017|grep -v 20160927)
							do 
								rm -rf ${dir_por}/$i >/dev/null 2>&1
							done
					fi
					if [ ${cp_file_szie} -gt 0 ];then	
						for mkdr in $(cat ${dir_diff}/cp_por_file${file_dir##*/})
							do
								mkdir -p $(dirname ${dir_por}/$mkdr) >/dev/null 2>&1
							done	
						for i in $(cat ${dir_diff}/cp_por_file${file_dir##*/}|grep -v 20160927)
							do 
								cp -rf ${dir_usb}/$i ${dir_por}/$i >/dev/null 2>&1
								Check_usb
							done
					fi
			else
				logOutput "begin" "${file_dir##*/}更新开始"
				mkdir -p ${por_file_dir}/${file_dir##*/}
				cp -rf ${usb_file_dir}/${file_dir##*/}/ ${por_file_dir}/ 
				Check_usb				
				logOutput "end" "${file_dir##*/}更新结束"
			fi
	done
logOutput "ok-3" "设备差异更新完成!"
}
check_portal() {
	find ${dir_por}/ -type f|grep -v cms|sed "s#${dir_por}/##g" |sort -k2,2 > ${dir_diff}/dev_por
	find ${dir_usb}/ -type f|grep -v cms|sed "s#${dir_usb}/##g"|sort -k2,2 > ${dir_diff}/usb_por
	diff ${dir_diff}/dev_por ${dir_diff}/usb_por |grep  ^+|sed '/+++/d;s/^+//g' > ${dir_diff}/cp_por_file
	diff ${dir_diff}/dev_por ${dir_diff}/usb_por |grep  ^-|sed '/---/d;s/^-//g' > ${dir_diff}/rm_por_file
	rm_por_szie=$(ls -l ${dir_diff}/rm_por_file|awk '{print $5}')
		if [ ${rm_por_szie} -gt 0 ];then
			logOutput "ok" 正在删除wfportal上的多余文件，请稍等......
			for i in $(cat ${dir_diff}/rm_por_file|grep -v 2017)
				do 
					rm -rf ${dir_por}/$i
				done
			logOutput "ok" wfportal文件删除完成
		fi	
	cp_por_szie=$(ls -l ${dir_diff}/cp_por_file|awk '{print $5}')
		if [ ${cp_por_szie} -gt 0 ];then
			for mkdri in $(cat ${dir_diff}/cp_por_file)
				do
					mkdir -p $(dirname ${dir_por}/$mkdri)
				done		
			for i in $(cat ${dir_diff}/cp_por_file)
				do 
					cp -rf ${dir_usb}/$i ${dir_por}/$i >/dev/null 2>&1
					Check_usb
				done
		fi
}
#删除空文件夹
rm_por_none_dir(){
	find ${dir_por}/ -type d >> ${dir_diff}/diff_por_dir
	for rm_por_dir_none in $(cat ${dir_diff}/diff_por_dir)
		do
			if [ $(ls ${rm_por_dir_none}|wc -l) -eq 0 ];then
				rm -rf ${rm_por_dir_none}
			fi
		done
}
#1、更新OBS
update_Obs() {
	if [ $(ps -w|grep obs|grep -v grep|wc -l) -gt 3 ]; then
		 logOutput "show" "OBS已存在，不更新obs" 
	else		 
		logOutput "begin" "开始更新 obs"  
		cp -ar ${mount_dir}/rj_obs/obs/* /mediacenter/airmedia/obs/ |tail -n 10
		Check_usb
		chmod -R 777 /mnt/disk/airmedia/obs/
		ps -w|grep obs|grep -v grep|awk '{print $2}'|xargs kill -9
		sh /mediacenter/airmedia/obs/start.sh &		 
	fi
	logOutput "ok-1" "obs更新成功"
}
#2、更新心跳
update_heartbeat() {
	mkdir -p /mediacenter/wangfan/
	logOutput begin "开始更新心跳"	
	if [  $(curl -s --connect-timeout 3 localhost:16621/api/getinfo >/dev/null;echo $?) -ne 0 ];then
		mkdir -p /mediacenter/airmedia/init/
		if [ ! -f /mediacenter/airmedia/init/init.sh ];then
			touch /mediacenter/airmedia/init/init.sh
			echo '#!/bin/sh' >> /mediacenter/airmedia/init/init.sh
			chmod 755 /mediacenter/airmedia/init/init.sh
		fi
		sed -i '/hb_daemon/d' /mediacenter/airmedia/init/init.sh
		echo "/mediacenter/wangfan/hb_daemon.sh &" >> /mediacenter/airmedia/init/init.sh
		cp -ar ${mount_dir}/heartbeat/ruijie_hb_daemon.sh /mediacenter/wangfan/hb_daemon.sh
		cp -ar ${mount_dir}/heartbeat/heartbeat.jar /mediacenter/wangfan/heartbeat.jar
		/mediacenter/wangfan/hb_daemon.sh &
	else 
		if [ ${hb_ver_usb} -gt ${hb_ver_por} ];then
			logOutput show "更新前心跳版本为$(cat ${mount_dir}/heartbeat/version)"
			cp -ar ${mount_dir}/heartbeat/heartbeat.jar /mediacenter/wangfan/heartbeat.jar.2			
		else
			logOutput ok "设备心跳版本高于U盘心跳版本，不更新心跳"			
		fi
	fi
	logOutput end "心跳更新结束"
	logOutput show "当前心跳版本为$(cat /mediacenter/wangfan/version)"
}
#地方局版本判断
local_check() {
	if [ -n "${LocalCheck}" ];then #当变量有值且，U盘中目录存在时，拷贝地方特色文件。
		if [ -d ${mount_dir}/local/${LocalCheck} ];then
			cp -ar ${mount_dir}/local/${LocalCheck}/* ${dir_por}/			
		else
			cp -ar ${mount_dir}/local/default/* ${dir_por}/			
		fi
	else
			cp -ar ${mount_dir}/local/default/* ${dir_por}/			
	fi
}
#删除空目录
rm_wfportal_none_dir(){
	find ${dir_por}/ -type d >> ${dir_diff}/diff_wfpor_dir
	for rm_wfpor_dir_none in $(cat ${dir_diff}/diff_wfpor_dir)
		do
			if [ $(ls ${rm_wfpor_dir_none}|wc -l) -eq 0 ];then
				rm -rf ${rm_wfpor_dir_none}
			fi
		done
}
#开始更新
Start_Update() {
	>/mnt/disk/update_progress.log
	rm -r ${dir_diff}/* >/dev/null 2>&1
	logOutput "show" "U盘版本号为：$(cat ${mount_dir}/local/USB_version)"
	logOutput "show" "设备升级前版本号为: $(awk -F'"' 'NR==2{print $4}' ${dir_por}/ver|tr -d '\n')"
	update_heartbeat
	update_Obs
	file_check	
	if [ ${usb_por_ver} -le ${dev_por_ver} ];then		
		logOutput "show" "设备版本高于U盘版本portal不更新"
	else
		check_portal
		cd ${dir_usb}
		cp -rf $(ls|grep -v cms) ${dir_por}/
	Check_usb
	local_check
	fi
	rm_por_none_dir
	#调用java程序，对视频和视频文件校验，输出和生成电影列表。
	movie_mun=$(java -jar ${mount_dir}/heartbeat/verifyVideo.jar ${dir_por}|grep video|awk -F: '{print $NF}')
	games_mun=$(java -jar ${mount_dir}/heartbeat/verifyVideo.jar ${dir_por}|grep games|awk -F: '{print $NF}')
	apks_mun=$(java -jar ${mount_dir}/heartbeat/verifyVideo.jar ${dir_por}|grep apks|awk -F: '{print $NF}')
	variety_mun=$(java -jar ${mount_dir}/heartbeat/verifyVideo.jar ${dir_por}|grep variety|awk -F: '{print $NF}')
	logOutput "movie" "当前电影总数为：${movie_mun}"
	logOutput "games" "当前游戏总数为：${games_mun}"
	logOutput "apks" "当前应用总数为：${apks_mun}"
	logOutput "variety" "当前综艺总数为：${variety_mun}"
	rm_wfportal_none_dir
	logOutput "show" "设备升级后版本号为: $(awk -F'"' 'NR==2{print $4}' ${dir_por}/ver|tr -d '\n')"
	logOutput "Finish-4" "U盘更新完成(成功),可以拔掉盘!!!!!!!!!"  
	check_upload_log
}
#日志上传检测
check_upload_log(){
	for i in `seq 1 3`
		do
			curl http://localhost:16621/op/usbupdateresult
			if [ $? -eq 0 ];then
				logOutput "show" "更新日志上传成功."
				break
			fi
		done
}

Start_git_file(){
	install_ssh
	download_wfportal
	download_script	
	Start_Update
}
Start_git_file