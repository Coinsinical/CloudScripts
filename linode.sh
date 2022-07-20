#!/bin/bash
#set -xv

##linode参数
regions=("ap-south" "ap-northeast" "ap-west" "ap-southeast" "eu-central" "eu-west" "ca-central" "us-central" "us-west" "us-east" "us-southeast")

##文件位置
file="./doc/api.txt"

##命令参数
access_token=$1

##基础函数
##获取实例状态


##获取账号硬盘

##功能性函数
##生成随机密码
randpw(){
	</dev/urandom tr -dc '12345qwertQWERTasdfgASDFGzxcvbZXCVB' | head -c12
}

##API相关
##检测API
check_api(){
	if [ -z $1 ];then		
		rm -rf ./doc/available.txt 
		for token in $(cat $file)
			do 
				if [ -n "$(curl -H "Authorization: Bearer $token" https://api.linode.com/v4/account -s | grep -E "errors")" ] 
					then
						echo "$token is invalid"
						echo $token >> ./doc/unavailable.txt
				else 
				  echo "$token" >> ./doc/available.txt
				fi
			done
		total="$(wc -l ./doc/api.txt | grep -Eo '[0-9]*')"	  
		available="$(wc -l ./doc/available.txt | grep -Eo '[0-9]*')"
		echo "共检测${total}个token，有效token${available}个" 
	else
		echo "正在检测API是否可用"
		if [ -n "$(curl -H "Authorization: Bearer $access_token" https://api.linode.com/v4/account -s | grep -E "errors")" ]
			then
				echo "$access_token is invalid"
				exit 0	
		fi
	fi
}

save_api(){
    isExist=false
	if [ ! -e "./doc/api.txt" ]
	then 
	    echo "API存储文件不存在，即将创建。。。"
		mkdir -p doc
		touch ./doc/api.txt
	else
	    for token in $(cat ./doc/api.txt )
		do
	        if [ access_token = token ];then
			    isExist=true
				echo "API已存在，请进行下一步操作"				
			    break
			fi
	    done
			
		if [ $isExist = false ];then
		    echo $access_token >> ./doc/api.txt
			echo "API已添加，请进行下一步操作"
		fi
	fi	 
}

##重启实例
reboot_linode(){
	id=$1
	if [ -z $id ];then
	    show_linode
		read -p  '请输入需要重启的实例ID: ' id
	fi
	
	curl -H "Content-Type: application/json" -H "Authorization: Bearer $access_token" -X POST https://api.linode.com/v4/linode/instances/$id/reboot -s
}

#重置密码
reset_password(){
	show_linode
	read -p "请输入需要重置密码的虚拟机ID：" id
	read -p "请输入root密码：（留空则生成随机密码）" password
	if [ -z $password ]
	then
		password=$(randpw)
	fi
	
	curl -H "Content-Type: application/json" -H "Authorization: Bearer $access_token" -X POST  https://api.linode.com/v4/linode/instances/$id/shutdown -s
	
	echo "等待实例关机，10s后重置密码"
	
	for i in {15..1}
		do     
			echo  -n  "${i}s后重置密码!"
			echo  -ne "\r\r"        ####echo -e 处理特殊字符  \r 光标移至行首，但不换行
			sleep 1
		done
		
	curl -H "Content-Type: application/json" -H "Authorization: Bearer $access_token" -X POST -d "{\"root_pass\": \"${password}\"}" https://api.linode.com/v4/linode/instances/$id/password -s
	
	echo "正在重置密码，等待30s后开机"
	
	for i in {30..1}
		do     
			echo  -n  "${i}s后开机!"
			echo  -ne "\r\r"        ####echo -e 处理特殊字符  \r 光标移至行首，但不换行
			sleep 1
		done
	reboot_linode $id

	echo -E "密码为${password}"
}


##重装系统
linode_rebuild(){
	show_linode
	read -p "请输入需要重装的虚拟机ID: " id
	read -p "请输入需要重装的系统: （默认为debian10）" image
	read -p "请输入root密码: （留空则生成随机密码）" password
	
	if [ -z $password ]
	then
		password=$(randpw)
	fi
	
	if [ -z $image ]
	then
		image=debian10
	fi
	
	curl -H "Content-Type: application/json" -H "Authorization: Bearer $access_token" -X POST -d "{\"image\": \"linode/$image\",\"root_pass\": \"$password\"}" https://api.linode.com/v4/linode/instances/$id/rebuild -s | json_pp
	
	echo "密码为$password"
}


#升级实例
linode_resize(){
	show_linode
	read -p "请输入需要升级的实例ID: " id
	read -p "请输入需要升级的配置:（默认为g6-nanode-2） " type
	
	if [ -z $type ];then
		type=g6-nanode-2
	fi
	
	curl -H "Content-Type: application/json" -H "Authorization: Bearer $access_token" -X POST -d "{\"type\":\"$type\"}' https://api.linode.com/v4/linode/instances/$id/resize"
}



#查看账户信息
show_account(){
	if [ -z $access_token ]
		then 
			echo "您现在还没有登陆账号"
			cat ./available.txt
			read -p "请输入需要登录账号的token:" access_token
			
	else
		echo  "您现在使用的token为${access_token}"
		read -p "是否需要更换账号？[Y/N](默认为N)" choice
		if (choice=='Y')
			then
				cat ./available.txt
				read -p "请输入新账号的token:" access_token
				show_menu
		else
			echo "请继续您的操作！"
			show_menu	
		fi
	fi
}


#查看实例配置种类
show_types(){
	curl https://api.linode.com/v4/linode/types -s | sed 's/},/\n/g'| grep -E '"id"|"lable" |"memory"|"vcpus"|"gpus"|"cpus"' | awk -F , '{print $1,$2}'| sed 's/{//g'
}

#查看实例地区
show_regions(){
	curl https://api.linode.com/v4/linode/region -s | json_pp
}

#创建虚拟机 地区：
create_linode(){
	read -p "请输入地区: " region
	read -p "请输入root密码: （留空则生成随机密码）" password
	read -p "请输入标签: （可以留空）" label
	read -p "请输入系统: （默认为debian10）" image
	read -p "请输入实例配置: （默认为g6-nanode-1）" type
	
	if [ -z $password ]
	then
		password=$(randpw)
	fi
	
	if [ -z $image ]
	then
		image=debian10
	fi
	
	if [ -z $type ]
	then
		type=g6-nanode-1
	fi
	
	curl -X POST https://api.linode.com/v4/linode/instances -H "Authorization: Bearer $access_token" -H "Content-type: application/json" -d "{\"type\": \"$type\", \"region\": \"$region\", \"image\": \"linode/$image\", \"root_pass\": \"$password\", \"label\":\"$label\"}" -s | sed 's/,/\n/g' | grep -E '"id":|"ipv4"|"ipv6"|"label"|"image"|"region"' | sed 's/{/\n /g'
	
	echo -E "密码为${password}"
}

# https://www.linode.com/docs/guides/rescue-and-rebuild/

#删除虚拟机
delete_linode(){
	show_linode
	read -p "请输入需要删除的虚拟机ID: " id
	if [ -n "$(curl -H "Authorization: Bearer $access_token" -X DELETE https://api.linode.com/v4/linode/instances/$id -s | grep -E "errors")" ] ;then
		echo "删除失败"
	else
		echo "删除成功"
	fi
}

#查看账户内虚拟机
show_linode(){
	instances=$(curl -H "Authorization: Bearer $access_token" https://api.linode.com/v4/linode/instances -s | sed 's/,/\n/g' | grep -E '"id":|"ipv4"|"ipv6"|"label"|"image"|"region"|"status"|"type"' | sed 's/{/\n /g')
	echo -e "$instances \n"
	number=$(echo -e "$instances \n" | grep "id" | wc -l)
	echo -e "您的账户共有$number台实例"
}

find_linode(){
	read -p "请输入需要查找的实例IP:" IP
	isFound=0
	for token in `cat ./available.txt`
		do 
			if [ -z $(curl -H "Authorization: Bearer $token" https://api.linode.com/v4/linode/instances -s | json_pp | grep -o "$IP") ]
				then
					continue
				else 
					access_token=${token}
					isFound=1
					break
			fi
		done
	if [ $isFound -eq 1 ];then
		show_linode
		echo "该实例所在账号API为${access_token}"
	else
		echo "未找到实例,该实例所在账户可能已被封禁！"
	fi
	
	echo "* 按回车键返回主菜单 *"
	show_menu
	
}


show_menu(){
	echo -ne "\r\r"
	echo -e  "
  ${green}linode 管理脚本${plain}
—————————————————————
  ${green} 0.${plain} 退出脚本
  
————— 账号相关 ——————

  ${green} 1.${plain} 登陆账号
  ${green} 2.${plain} 检测API
  
————— 实例相关 ——————

  ${green} 3.${plain} 创建实例
  ${green} 4.${plain} 删除实例
  ${green} 5.${plain} 查看实例 
  ${green} 6.${plain} 重置密码
  ${green} 7.${plain} 搜寻实例
  ${green} 8.${plain} 重装实例
  ${green} 9.${plain} 重启实例
  ${green}10.${plain} 升级实例
  
  
—————————————————————
 "
	echo && read -p "请输入选择 [0-8]: " num
	case "$num" in
		0)exit 0
		;;
		1)show_account
		;;
		2)check_api
		;;
		3)create_linode
		;;
		4)delete_linode
		;;
		5)show_linode
		;;
		6)reset_password
		;;
		7)find_linode
		;;
		8)linode_rebuild
		;;
		9)reboot_linode
		;;
		10)linode_resize
		;;
		*) echo -e "${red}\n请输入正确的数字 [0-10]${plain}" && show_menu
		;;
	esac	
}


check_api 1 ##使用脚本即对API可用性进行检查
save_api ##保存可用API
show_menu