#!/bin/sh
#check movie

#1.获取id,并获取,image,image_hori,title,如果图片不存在,就输出title,file is loss,如果都存在go on
#2.拼接id的文件地址,
#3.从id中获取name,file,image,如果name=title,
#4.就查找文件是否存在,文件都存在就认为是OK的.如果不存在,就输出文件loss

por_dir="/mnt/disk/airmedia/wfportal"
video_dir="${por_dir}/data/appvideo"
ok_num=0
nok_num=0
loss_file=0

check_file(){
	MAIN=$*
	for chk_file in ${MAIN}
		do
			if [ $(ls -lt ${por_dir}/${chk_file} >/dev/null ;echo $?) -ne 0 ];then
				echo "${chk_file} not exist,please check check file!"
				let loss_file++
			fi
		done
}

check_movie(){
	sleep 2
	movie_code=$(curl -w %{http_code} -s -o /dev/null http://www.wangfanwifi.com/${movie})
	if [ ${movie_code} -eq 200 ];then
		echo "${title} is ok"
		let ok_num++
	else
		echo "please check ${title}"
		let nok_num++
	fi
}

for file in `awk '{printf"%s" ,$0}' ${video_dir}/list/1|sed 's/[[:space:]]//g'|sed 's/,{/\n,{/g'`
	do 
		id_num=$(echo $file|awk -F'"' '{print $8}')
		image=$(echo $file|awk -F'"' '{print $16}')
		image_hori=$(echo $file|awk -F'"' '{print $20}')
		title=$(echo $file|awk -F'"' '{print $28}')
		movie=$(awk -F'"' '{print $20}' ${por_dir}/${id_num})
		
		check_file ${id_num} ${image} ${image_hori} ${movie}
		check_movie
	done

echo "===================satrt====================="
echo "可播放的电影有${ok_num}部"
echo "不可播放的电影有${nok_num}部"
echo "文件缺少的电影有${loss_file}"
echo "===================end====================="