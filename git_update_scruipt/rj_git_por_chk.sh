#!/bin/sh
cd /mediacenter
if [ ! -d /mediacenter/git-repo/portal_train ];then
        mkdir -p /mediacenter/git-repo && cd git-repo
        git clone ssh://git@git.ihangmei.com:65022/H5-web/portal_train.git
fi

cd /mediacenter/git-repo/portal_train
if [ $(git pull origin testmaster|grep -c changed) -gt 0 ];then		
       cp -r /mediacenter/git-repo/portal_train/* /mediacenter/airmedia/portal/
fi
