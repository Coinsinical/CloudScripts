#!/bin/bash

access_token=$1

#查看账户信息
show_account(){
	echo -e "$access_token"
}


#查看实例配置种类
show_types(){
	curl https://api.linode.com/v4/linode/types |sed 's/},/\n/g'| grep -E '"id"|"lable" |"memory"|"vcpus"|"gpus"|"cpus"' |awk -F , '{print $1,$2}'| sed 's/{//g'
}

#创建虚拟机 地区：
create_linode(){
	read -p "请输入地区: " region
	read -p "请输入root密码: " password
	read -p "请输入标签: " label
	read -p "请输入系统: " image
	read -p "请输入实例配置: " type
	curl -H "Content-Type: application/json" -H "Authorization: Bearer $access_token" -X POST -d ' {"image": ""$image"","root_pass": ""$password"","label": ""$label"","type": ""$type"","region": ""$region"" }' https://api.linode.com/v4/linode/instances
}

#删除虚拟机
delete_linode(){
	show_linode
	read -p "请输入需要删除的虚拟机ID: " id
	curl -H "Authorization: Bearer $access_token" -X DELETE https://api.linode.com/v4/linode/instances/$id
}

#查看账户内虚拟机
show_linode(){
	instances=`curl -H "Authorization: Bearer $access_token" https://api.linode.com/v4/linode/instances |sed 's/,/\n/g' | grep -E '"id":|"ipv4"|"ipv6"|"label"|"image"|"region"' | sed 's/{/\n /g'`
	echo -e "$instances \n"
	number=$(echo -e "$instances \n" | grep "id" | wc -l)
	echo -e "您的账户共有$number台实例"
}


show_menu(){
	echo -e  "
  ${green}linode 管理脚本${plain}
————————————————
  ${green}0.${plain} 退出脚本
————————————————
  ${green}1.${plain} 登陆账号
————————————————
  ${green}2.${plain} 创建实例
  ${green}3.${plain} 删除实例
  ${green}4.${plain} 查看实例  
————————————————
 "
	echo && read -p "请输入选择 [0-4]: " num
	case "$num" in
		0)exit 0
		;;
		1)show_account
		;;
		2)create_linode
		;;
		3)delete_linode
		;;
		4)show_linode
		;;
		*) echo -e "${red}\n请输入正确的数字 [0-4]${plain}" && show_menu
		;;
	esac	
}
	
show_menu