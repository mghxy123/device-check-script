#!/bin/sh
export PATH=$PATH:/usr/local/bin/:/usr/local/libexec
cd /mnt/disk
if [ ! -d /mnt/disk/git-repo/portal_train ];then
        mkdir -p /mnt/disk/git-repo && cd git-repo
        git clone ssh://git@git.ihangmei.com:65022/H5-web/portal_train.git
fi
while :
do
    cd /mnt/disk/git-repo/portal_train
    if [ $(git pull origin crystal|grep -c changed) -gt 0 ];then		
           cp -r /mnt/disk/git-repo/portal_train/* /mnt/disk/airmedia/wfportal/
    fi
    sleep 60;
done
