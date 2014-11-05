#!/usr/local/bin/bash

# where the sources are
SRCDIR='/usr/local/src'

# where to look for nginx
NGX_PREFIX='/usr/local/nginx'

# what new nginx version we should get
NGX_NEW='1.4.4'

# hello
echo "Hiii!"

if [ "$1" = "" ]; then
    if [ -f $NGX_PREFIX/sbin/nginx ]; then 
	NGX_VER=`$NGX_PREFIX/sbin/nginx -V 2>&1|grep "nginx version"|cut -d '/' -f2`
	echo "NGINX version "$NGX_VER" found"
	if [ -f $SRCDIR/nginx-$NGX_VER/nginx.sh ]; then 
	    echo "NGINX build config file nginx.sh found."
	    echo "Use command: "$0" update"
	fi
    else
	echo "No NGINX installation found! Please make sure NGX_PREFIX variable in this file is set correctly" && exit 1
    fi

elif [ $1 = "update" ]; then
{

# some other vars, do not edit!
# find out installed nginx version
export NGX_VER=`$NGX_PREFIX/sbin/nginx -V 2>&1|grep "nginx version"|cut -d '/' -f2`
# where to backup nginx config
NGX_CONFBAK=$NGX_PREFIX'/backup_conf_'$NGX_VER'.tar.gz'
NGX_BINBAK=$NGX_PREFIX'/backup_binary_'$NGX_VER'.tar.gz'

if [ -d $SRCDIR ]; then
  if [ -f $SRCDIR/nginx-$NGX_VER/nginx.sh ]; then
    echo "Backing up NGINX config to "$NGX_CONFBAK && tar -cHzpf $NGX_CONFBAK $NGX_PREFIX/conf
    echo "Backing up NGINX binary to "$NGX_BINBAK && tar -cHzpf $NGX_BINBAK $NGX_PREFIX/sbin/nginx
    cd $SRCDIR && fetch http://nginx.org/download/nginx-$NGX_NEW.tar.gz
    tar -xf nginx-$NGX_NEW.tar.gz
    cp $SRCDIR/nginx-$NGX_VER/nginx.sh $SRCDIR/nginx-$NGX_NEW/
    cd $SRCDIR/nginx-$NGX_NEW/ && sh ./nginx.sh && make -j4 && make install && echo "NGINX version "$NGX_NEW" is now installed." && echo "Old NGINX "$NGX_VER" binary is available at "$NGX_BINBAK
    	echo ""
    	$NGX_PREFIX/sbin/nginx -t
    	echo ""
	if [ -f $NGX_PREFIX/sbin/nginxctl ]; then
	    echo "It's Done.... Please restart NGINX with the following command:"
	    echo $NGX_PREFIX"/sbin/nginxctl stop && sleep 5 && "$NGX_PREFIX"/sbin/nginxctl start"
	else
	    echo "No nginxctl found. Please find out how to restart NGINX yourself." && exit 0
	fi
    unset NGX_VER
  else
    echo "No nginx.sh file found! mimo_mode=ON! Figure out what to do yourself!" && exit 1
  fi
fi
}
else
    echo "Sorry, what?" && exit 0
fi
