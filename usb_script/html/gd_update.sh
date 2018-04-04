#!/bin/sh
#auth:huxianyong
#date:20170509
#action:GD usb_update_script
#指定文件目录
#########################################################################################################
#说明：
#1、在设备版本高于U盘版本时，就会对除CMS之外的整个portal对比更新(之对比文件，不比较大小和时间，有就更新)
#2、在设备版本低于U盘版本时，U盘会对整个portal进行覆盖更新
#3、在设备上的资源文件会做增量更新，设备缺什么就更新什么
#4、此U盘会自动更新更新脚本和黑白名单文件,一旦发现问题只需要在后台上修改即可
#5、此U盘还会自动更新portal,让其于线上一直,U盘一更新,设备上都是最新的东西
#6、固件的命名方式为114为版本号，后面为-update.bin格式不能变
#7、wfportal必须是一个完整的目录
#8、U盘根目录下有:gd_firmware,gd_rproxyd,git,heartbeat,list,wfportal,gd_obs,html,ruijie_obs,local,tmp,等11个目录和copy.sh文件
#9、增加了地方局的特色判断，给各个地方局拷贝不同的版本
#10、在此脚本之后的目录或文件，必须要存在2017，不然会被删除，此脚本只适用于2017年
#11、此脚本会删除nginx在wangfan目录下的所有未上传文件，还有删除
#12、此脚本不拷贝往返APP，也不做各个路局的版本判断
#13、APP新增了U盘版本展示，
#14、此脚本具有断电后,下次再次更新不会重复之前的动作的功能
#15、已加入王朝的最新java包,脚本已修改对于,电影,游戏,应用,综艺的动态列表生成
#########################################################################################################
#导入java环境变量，系统本身不回去调用环境变量，需要手动去调用，不然掉不了java程序
export JAVA_HOME=/mnt/storage/yuqi/jre
export CLASSPATH=.:$JAVA_HOME/lib/rt.jar:$JAVA_HOME/lib/tools.jar
export PATH=$PATH:$JAVA_HOME/bin:/mnt/storage/yuqi/python/bin:/mnt/storage/yuqi/nginx/sbin:/mnt/storage/yuqi/sqlite3/bin:/mnt/storage/yuqi/php/bin:/mnt/storage/yuqi/php/sbin
#写入变量目录
mount_dir=/mnt/usb
dir_por=/mnt/disk/airmedia/wfportal
usb_por=/mnt/usb/wfportal
dir_diff=/mnt/disk/difffile
git_dir=/mnt/usb/tmp/git_file
usb_file_dir=${usb_por}/cms
por_file_dir=${dir_por}/cms
LocalCheck=$(awk -F'"' 'NR==2{print $4}' ${dir_por}/config.json)
hb_ver_usb=$(cat ${mount_dir}/heartbeat/version|tr -d "[a-x]")
hb_ver_por=$(cat /mnt/disk/wangfan/version|tr -d "[a-x]")
dev_fir_ver=$(awk -F'(' '{print $1}' /etc/version |awk -F '.' '{print $1$2$3}')
usb_fir_ver=$(ls -t ${mount_dir}/gd_firmware/|head -n1|awk -F'-' '{print $1}')
#usb_por_ver=$(awk -F '_' 'NR==2 {print $2}' ${usb_por}/ver|tr -d '"'|awk -F '.' '{print $1$2$3}')
dev_por_ver=$(awk -F '_' 'NR==2 {print $2}' ${dir_por}/ver|tr -d '"'|awk -F '.' '{print $1$2$3}'|sed 's/,//g')

install_git(){
	if [ $(git >/dev/null;echo $?) -ne 1 ];then 
		cp -r /mnt/usb/git/lib/* /usr/lib/
		tar xvf /mnt/usb/git/git.tar.gz -C /mnt/storage/yuqi/	
	fi
	if [ ! -f /usr/bin/git ];then
		ln -s /mnt/storage/yuqi/git/bin/git /usr/bin/git
	fi
	if [ ! -f /usr/lib/libiconv.so.2 ];then
		ln -s /usr/lib/libiconv.so.2.4.0  /usr/lib/libiconv.so.2
	fi
}

install_ssh(){
	if [  $(ssh >/dev/null;echo $?) -ne 255 ];then
		sed -i '/\/usr\/local\/libexec/d' /etc/profile
		echo "export PATH=$PATH:/usr/local/bin/:/usr/local/libexec" >>  /etc/profile
		sync /etc/profile	
		cp -r /mnt/usb/git/sshd/* /usr/local/
		cp -r /mnt/usb/git/.ssh /root/
		chmod 755 /usr/local/bin/*
		chmod 755 /usr/local/sbin/*
		chmod 755 /usr/local/libexec/*
		chmod 700 /root/.ssh
		chmod 600 /root/.ssh/*	
		export PATH=$PATH:/usr/local/bin/:/usr/local/libexec
	fi	
}

download_wfportal(){
	cd ${git_dir}
	if [ ! -d ${git_dir}/wfportal ];then
        mkdir -p ${git_dir}/wfportal && cd ${git_dir}
		git clone ssh://git@git.ihangmei.com:65022/huxianyong/wfportal.git
        if [ $? -eq 0 ];then
			cd ${git_dir}/wfportal/wfportal/
			cp -r `ls` /mnt/usb/wfportal/
		fi
	elif [ $(cd wfportal;git pull| grep -c changed) -gt 0 ];then
		logOutput "begin" "U盘portal版本正在升级,请稍等!"
        cp -r ${git_dir}/wfportal/wfportal/* /mnt/usb/wfportal/
		logOutput "end" "U盘portal版本升级完成"
    fi
}

download_script(){
	cd ${git_dir}
	if [ ! -d ${git_dir}/script ];then
        mkdir -p ${git_dir}/script && cd ${git_dir}
		git clone ssh://git@git.ihangmei.com:65022/huxianyong/script.git
        if [ $? -eq 0 ];then
			cp ${git_dir}/script/gd_update.sh ${git_dir}/script/gd_update.sh.1
		fi
    elif [ $(cd script;git pull| grep -c changed) -gt 0 ];then
		logOutput "begin" "U盘更新脚本正在升级,请稍等!"
		cp ${git_dir}/script/gd_update.sh ${git_dir}/script/gd_update.sh.1
		logOutput "end" "U盘更新脚本升级完成!"
    fi
}

download_list(){
	cd ${git_dir}
	if [ ! -d ${git_dir}/new_list ];then
        mkdir -p ${git_dir}/new_list && cd ${git_dir}
		git clone ssh://git@git.ihangmei.com:65022/huxianyong/new_list.git
        if [ $? -eq 0 ];then	
			cp ${git_dir}/new_list/* /mnt/usb/list/
		fi
    elif [ $(cd new_list;git pull| grep -c changed) -gt 0 ];then
		logOutput "begin" "U盘黑白名单正在升级!"
        cp ${git_dir}/new_list/* /mnt/usb/list/
		logOutput "end" "U盘黑白名单正在完成!"
    fi
}
Chk_usb_por() {
	find ${git_dir}/wfportal/wfportal/ -type f|grep -v cms|xargs ls -l|awk '{print $5,$NF}'|sed "s#/mnt/usb/tmp/git_file/wfportal/wfportal/##g" |sort -k2,2 > ${dir_diff}/git_usb_por
	find ${usb_por}/ -type f|grep -v cms|xargs ls -l|awk '{print $5,$NF}'|sed "s#/mnt/usb/wfportal/##g"|sort -k2,2 > ${dir_diff}/usb_wfpor
	diff ${dir_diff}/git_usb_por ${dir_diff}/usb_wfpor |grep  ^-|sed '/---/d;s/^-//g' > ${dir_diff}/up_cp_por_file
	up_cp_por_sz=$(ls -l ${dir_diff}/up_cp_por_file|awk '{print $5}')
		if [ ${up_cp_por_sz} -gt 0 ];then
#			logOutput "ok" 正在拷贝wfportal文件中，请稍等......
			for mkdri in $(cat ${dir_diff}/up_cp_por_file)
				do
					mkdir -p $(dirname ${git_dir}/${mkdri})
				done		
			for i in $(cat ${dir_diff}/up_cp_por_file)
				do 
					cp -rf ${git_dir}/wfportal/wfportal/$i ${mount_dir}/wfportal/$i
				done
#			logOutput "ok" wfportal文件拷贝完成
		fi
}

logOutput() {
    now=$(date +'[%Y-%m-%d %H:%M:%S]')
    echo "${now} [$1] $2" >> /mnt/disk/update_progress.log
}

Check_Wfportal() {
	find ${dir_por}/ -type f|grep -v cms|sed "s#${dir_por}##g" |sort -k2,2 > ${dir_diff}/dev_por_file
	find ${usb_por}/ -type f|grep -v cms|sed "s#${usb_por}##g"|sort -k2,2 > ${dir_diff}/usb_wfpor
	diff ${dir_diff}/dev_por_file ${dir_diff}/usb_wfpor |grep  ^+|sed '/+++/d;s/^+//g' > ${dir_diff}/cp_por_file
	diff ${dir_diff}/dev_por_file ${dir_diff}/usb_wfpor |grep  ^-|sed '/---/d;s/^-//g' > ${dir_diff}/rm_por_file
	rm_por_sz=$(ls -l ${dir_diff}/rm_por_file|awk '{print $5}')
		if [ ${rm_por_sz} -gt 0 ];then
			logOutput "ok" "正在删除wfportal上的多余文件，请稍等......"
			#删除U盘中没有的文件，排除2017年的，和往返的app包
			for i in $(cat ${dir_diff}/rm_por_file|grep -v 2017)
				do 
					rm -rf ${dir_por}/$i
				done
			logOutput "ok" "wfportal文件删除完成"
		fi	
	cp_por_sz=$(ls -l ${dir_diff}/cp_por_file|awk '{print $5}')
		if [ ${cp_por_sz} -gt 0 ];then
			logOutput "ok" "正在拷贝wfportal文件中，请稍等......"
			for mkdri in $(cat ${dir_diff}/cp_por_file)
				do
					mkdir -p $(dirname ${dir_por}/$mkdri)
				done		
			for i in $(cat ${dir_diff}/cp_por_file)
				do 
					cp -rf ${usb_por}/$i ${dir_por}/$i
				done
			logOutput "ok" "wfportal文件拷贝完成"
		fi
	
}

Cms_File_Check() {
logOutput "ok-1" "差异更新开始"
mkdir -p ${dir_diff}
mkdir -p ${dir_por}
for file_dir in ${usb_file_dir}/*
	do
		logOutput "show" "正在更新${file_dir##*/}"
		find ${por_file_dir}/${file_dir##*/}/ -type f > /dev/null 2>&1
			if [ $? -eq 0 ];then #检查设备上是否存在目录不存在直接拷贝目录
				find ${por_file_dir}/${file_dir##*/} -type f |awk '{ print $NF}'|xargs ls -l|awk '{print $5,$NF}'|sed "s#${dir_por}/##g" |sort -k2,2> ${dir_diff}/por_${file_dir##*/}
				find ${usb_file_dir}/${file_dir##*/} -type f |awk '{ print $NF}'|xargs ls -l|awk '{print $5,$NF}'|sed "s#${usb_por}/##g"|sort -k2,2  > ${dir_diff}/usb_${file_dir##*/}
				diff ${dir_diff}/por_${file_dir##*/} ${dir_diff}/usb_${file_dir##*/} |grep ^+|sed '/+++/d'|awk '{print $2}' > ${dir_diff}/cp_por_file_${file_dir##*/}
				diff ${dir_diff}/por_${file_dir##*/} ${dir_diff}/usb_${file_dir##*/} |grep ^-|sed '/---/d'|awk '{print $2}' > ${dir_diff}/rm_por_file_${file_dir##*/}
					cp_file_szie=$(ls -l ${dir_diff}/cp_por_file_${file_dir##*/} |awk '{print $5}')
					rm_file_szie=$(ls -l ${dir_diff}/rm_por_file_${file_dir##*/} |awk '{print $5}')
					if [ ${rm_file_szie} -gt 0 ];then
						for i in $(cat ${dir_diff}/rm_por_file_${file_dir##*/}|grep -v 2017|grep -v 20160927)
							do 
								rm -rf ${dir_por}/$i >/dev/null 2>&1
							done
					fi
					if [ ${cp_file_szie} -gt 0 ];then	
						for mkdr in $(cat ${dir_diff}/cp_por_file_${file_dir##*/})
							do
								mkdir -p $(dirname ${dir_por}/$mkdr) >/dev/null 2>&1
							done
						for i in $(cat ${dir_diff}/cp_por_file_${file_dir##*/}|grep -v 20160927)
							do 
								cp -rf ${usb_por}/$i ${dir_por}/$i >/dev/null 2>&1
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
logOutput "ok-2" "设备差异更新完成!"
}
#安装反向代理
Update_Rproxyd() {
	if [ $(ps aux|grep -i -c /sbin/rproxyd) -lt 2 ]; then
		if [ -d ${mount_dir}/gd_rproxyd ]; then
			mkdir -p /mnt/disk/download/
			unzip -o ${mount_dir}/gd_rproxyd/rproxyd.zip -d /mnt/disk/download/ |tail -n 10
			sh /mnt/disk/download/rproxyd/install.sh
		fi
		logOutput "ok" "跳过部署远程反向代理"  
	else
		logOutput "ok" "远程反向代理已经安装"  
	fi
}
Update_Obs() {
	if [ $(ps -ef|grep obs|grep -v grep|wc -l) -gt 3 ]; then
		 logOutput "show" "obs已存在，不更新obs" 
	else		 
		logOutput "show" "开始更新 obs"  
		cp -ar ${mount_dir}/gd_obs/obs /mnt/disk/airmedia/
		Check_usb
		chmod -R 777 ${dir_por}/obs/
		ps aux|grep obs|grep -v grep|awk '{print $2}'|xargs kill -9
		/bin/sh ${dir_por}/obs/start.sh	
	fi
	logOutput "ok-3" "obs更新完成" 
}
Update_Heartbeat() {
	logOutput "begin" "开始更新心跳"
	mkdir -p /mnt/disk/wangfan/
	if [  $(curl -s --connect-timeout 3 localhost:16621/api/getinfo >/dev/null;echo $?) -ne 0 ];then
		cp -ar ${mount_dir}/heartbeat/gaoda_hb_daemon.sh /mnt/disk/wangfan/hb_daemon.sh
		cp -ar ${mount_dir}/heartbeat/heartbeat.jar /mnt/disk/wangfan/heartbeat.jar
		Check_usb
		/bin/sh /mnt/disk/wangfan/hb_daemon.sh &
	else	
		if [ ${hb_ver_por} -lt ${hb_ver_usb} ];then #心跳如果设备版本小于U盘版本
			cp -rf ${mount_dir}/heartbeat/heartbeat.jar /mnt/disk/wangfan/heartbeat.jar.2			  
			Check_usb
			logOutput "show" "更新后心跳版本$(cat ${mount_dir}/heartbeat/version)"
		else
			logOutput "ok" "设备心跳版本高于U盘心跳版本，不更新心跳"
			logOutput "show" "当前心跳版本为$(cat /mnt/disk/wangfan/version)"
		fi
	fi
	logOutput "end" "心跳更新结束"	
}
#地方局版本判断
local_check() {	
	if [ -n "${LocalCheck}" ];then #当变量有值且，U盘中目录存在时，拷贝地方特色文件。
		if [ -d /mnt/usb/local/${LocalCheck} ];then
			cp -ar /mnt/usb/local/${LocalCheck}/* ${dir_por}/
		else
			cp -ar /mnt/usb/local/default/* ${dir_por}/			
		fi
	else
			cp -ar /mnt/usb/local/default/* ${dir_por}/			
	fi
}
#更新固件版本(把固件版本号作为，固件的文件名)
Update_Firmware() {
	if [ -d ${mount_dir}/gd_firmware ]; then
		if [ ${usb_fir_ver} -gt ${dev_fir_ver} ]; then
			logOutput "show" "未升级前固件版本$(awk '{print $1}' /etc/version)"  
			firmware_2_update=$(basename $(ls -t /mnt/usb/gd_firmware/*update.bin)|head -n1)
			#拷贝固件到硬盘上再进行升级
			mkdir -p /mnt/disk/download/
			cp -f ${mount_dir}/gd_firmware/${firmware_2_update} /mnt/disk/download/
			Check_usb
			logOutput "begin" "开始升级固件"  
			down_update -s -p /mnt/disk/download/${firmware_2_update}
			logOutput "end" "固件升级结束,设备将在下次重启后生效"  
		else
			# 固件版本检查通过,直接退出
			logOutput "ok" "固件版本正常，跳过固件更新！"
		fi
	else
		logOutput "wain" "U盘没有固件，请检查U盘！"
	fi
		logOutput "show" "当前固件版本$(awk '{print $1}' /etc/version)"  
}
Update_Portal() {
	usb_por_ver=$(awk -F '_' 'NR==2 {print $2}' ${usb_por}/ver|tr -d '"'|awk -F '.' '{print $1$2$3}'|sed 's/,//g')
	#变量放在这里是为了获取git更新后的版本号,而不是更新之前的版本号,更新之前的版本号会导致portal不更新的情况
	Update_Obs
	Update_Rproxyd
	Update_Firmware	
	if [ ${usb_por_ver} -le ${dev_por_ver} ];then			
		logOutput "show" "设备版本高于U盘版本portal不更新"		
	else
		Check_Wfportal
		cd ${usb_por}/
		cp -ar $(ls|grep -v cms) ${dir_por}/		
		Check_usb
		local_check		
	fi
	#拷贝完整的电影文件，给java做参考对比
	cp -ar ${mount_dir}/list/init.sh ${dir_por}/init.sh
	chmod 755  ${dir_por}/init.sh
	cp -ar ${mount_dir}/list/dns.blacklist /etc/dns.blacklist
	cp -ar ${mount_dir}/list/white_list.conf /etc/white_list.conf		
	#调用java程序，对视频和视频文件校验，输出和生成电影列表。
	movie_mun=$(java -jar ${mount_dir}/heartbeat/check_all_list.jar ${dir_por}|grep appvideo|awk -F: '{print $NF}')
	games_mun=$(java -jar ${mount_dir}/heartbeat/check_all_list.jar ${dir_por}|grep games|awk -F: '{print $NF}')
	apks_mun=$(java -jar ${mount_dir}/heartbeat/check_all_list.jar ${dir_por}|grep apks|awk -F: '{print $NF}')
	variety_mun=$(java -jar ${mount_dir}/heartbeat/check_all_list.jar ${dir_por}|grep variety|awk -F: '{print $NF}')
	logOutput "movie" "当前电影总数为：${movie_mun}"
	logOutput "games" "当前游戏总数为：${games_mun}"
	logOutput "apks" "当前应用总数为：${apks_mun}"
	logOutput "variety" "当前综艺总数为：${variety_mun}"
	logOutput "show" "portal升级后版本号为: $(awk -F'"' 'NR==2{print $4}' ${dir_por}/ver|tr -d '\n')"
}
Rm_File_Check(){
	logOutput "show" "正在检测是否存在多余的文件"
	#检测是否存在老portal，存在就删除
	if [ -d /mnt/disk/airmedia/portal ];then
		logOutput "show" "正在删除老portal，请稍等...."
		rm -rf /mnt/disk/airmedia/ >/dev/null 2>&1	
		logOutput "ok" "老portal删除完成"
	fi
		rm  -f /mnt/disk/wangfan/download.14* >/dev/null 2>&1	
		rm  -f /mnt/disk/wangfan/nginx.tmp.14* >/dev/null 2>&1	
		#删除多余文件结构
	for file_dir in $(ls ${por_file_dir})
	do 
		if [ ! -d ${usb_file_dir}/${file_dir} ];then 
			rm -rf  ${por_file_dir}/${file_dir}
		fi
	done
	logOutput "ok" "多余文件检测删除完成"
}
#删除空目录
rm_wfportal_none_dir(){
	find ${dir_por}/ -type d > ${dir_diff}/diff_wfpor_dir
	for rm_wfpor_dir_none in $(cat ${dir_diff}/diff_wfpor_dir)
		do
			if [ $(ls ${rm_wfpor_dir_none}|wc -l) -eq 0 ];then
				rm -rf ${rm_wfpor_dir_none}
			fi
		done
}
#检查portal除cms之外的文件，如果设备上有就不更新，只看文件不看大小，而且只有在不更新portal的情况下才会检查
Start_Update(){
	Rm_File_Check
	Update_Heartbeat	
	Cms_File_Check
	Update_Portal
	Check_usb
	rm_wfportal_none_dir
	logOutput "Finish-4" "U盘更新完成(成功),可以拔掉盘!!!!!!!!!"  
	check_upload_log
}
#检查U盘
Check_usb(){
	if [ $? -ne 0 ];then
 	    logOutput "error-1" "U盘状态异常,更新失败！！！"  
		check_upload_log
		ps -ef|grep preinst|grep -v grep|awk '{print $2}' |xargs kill
		exit
	fi
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
	> /mnt/disk/update_progress.log
	rm -f ${dir_diff}/* >/dev/null 2>&1
	logOutput "show" "U盘版本号为：$(cat /mnt/usb/local/USB_version)"
	logOutput "show" "portal升级前版本号为: $(awk -F'"' 'NR==2{print $4}' ${dir_por}/ver|tr -d '\n')"
#	install_git
	install_ssh
	download_wfportal
	download_script
	download_list
	Start_Update
}
Start_git_file