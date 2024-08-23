#!/bin/bash
#set -xv

## 文件结构
# CloudSripts
# │
# ├─linode.sh
# │
# └─data
#     └─Linode
#         │-regions.txt
#         │
#         └─Tokens
#             ├─all.txt
#             ├─valid.txt
#             │
#             ├─disabled
#             │  └─disabled_example_token
#             │          ├─info.txt
#             │          └─vm.txt
#             │
#             └─valid
#                 └─valid_example_token
#                         ├─info.txt
#                         └─vm.txt


##linode参数
regions=("ap-south" "id-cgk" "ap-northeast" "jp-osa" "ap-west" "in-maa" "ap-southeast" "au-mel" "eu-central" "eu-west" "gb-lon" "fr-par" "se-sto" "it-mil" "nl-ams" "es-mad" "ca-central" "us-central" "us-west" "us-east" "us-southeast" "us-ord" "us-iad" "us-sea" "us-mia" "us-lax" "br-gru")

##文件位置
linode_root_path="./data/Linode"


##命令参数
access_token=$1

##基础函数
##获取实例状态


##获取账号硬盘

##功能性函数
## 等待动画
## 采用awk进行计算

spinner() {
    local consume_time=${1:-10}
    local spinstr='|/-\'
    local count=0

    consume_time=$((consume_time * 10))
    while [ $consume_time -ge 0 ]; do
        local char=${spinstr:$count:1}
        echo -ne "\r${2} ${char}"
        sleep 0.1
        consume_time=$((consume_time - 1))
        count=$(( (count + 1) % 4 ))
    done
}

## 是否退出脚本
is_continue(){
	local choice='y'
	read -p "是否退出？（默认退出）[y/n]" choice
	choice=${choice:-y}

	if [ $choice = y ]
	then
		exit 0
	else
		show_menu
	fi
}

## json转换为表格展示
json_to_table(){
	local info=$1
	if [ $(echo $1 | jq -r 'type') != "array" ]
	then
		info="[$1]"
	fi

	if [ $# -eq 1 ]
	then
		echo $info | jq -r '.[] | [.[]] | @tsv' | column -t
	fi
}

##检测文件

# 函数：检测和安装依赖
# 参数：依赖列表
check_dependencies() {
	local dependencies=("$@")

	 # 遍历依赖列表
    for dependency in "${dependencies[@]}"
    do
		if ! command -v "$dependency" &> /dev/null; then
			echo "$dependency 未安装，开始安装..."

			# 检查包管理器类型
			if command -v apt-get &> /dev/null; then
				# Ubuntu 或 Debian
				apt-get update
				apt-get install -y "${dependency}"
			elif command -v yum &> /dev/null; then
				# CentOS 或 RHEL
				yum install -y "${dependency}"
			elif command -v dnf &> /dev/null; then
				# Fedora
				dnf install -y "${dependency}"
			else
				echo "无法确定包管理器类型，请手动安装 ${dependency}。"
				exit 1
			fi

			# 再次检查 $dependency 是否安装成功
			if ! command -v ${dependency} &> /dev/null; then
				echo "${dependency} 安装失败，请手动安装。"
				exit 1
			fi

			echo "${dependency} 安装成功。"
		fi
	done
}

##生成随机密码
randpw(){
	</dev/urandom tr -dc '12345qwertQWERTasdfgASDFGzxcvbZXCVB' | head -c12
}

# 获取优惠码
get_promo_code()
{
	 promo_code=$(curl https://www.linode.com/lp/affiliate-referral/ -s | grep -oE -m 1 'href="[^"]*signup\?promo=([^"]*)"' | sed -E 's/href="[^"]*\?promo=([^"]*)"/\1/')
}

##API相关
##检测API
check_api(){
	if [ -z $1 ];then
		tokens="$(cat ${linode_root_path}/Tokens/valid.txt)"
		for token in $tokens
			do
				resp=$(curl -H "Content-Type: application/json" -H "Authorization: Bearer $token" -X GET  https://api.linode.com/v4/account -s)
				if $(echo $resp | jq 'has("errors")')
					then
						echo -e "${token} \t invalid"
						sed -i "/${token}/d" "${linode_root_path}/Tokens/valid.txt"
						if [ -e "${linode_root_path}/Tokens/valid/${token}" ];then
						    mv "${linode_root_path}/Tokens/valid/${token}" "${linode_root_path}/Tokens/disabled/${token}"
						else
						    touch "${linode_root_path}/Tokens/disabled/${token}"
					    fi
				else
					echo -e "${token} \t valid"
					credit=$(echo ${resp} | jq -r '{balance, balance_uninvoiced, "credit_remaining": .active_promotions[0].credit_remaining, "credit_expire_dt": .active_promotions[0].expire_dt}')
					update_credit
					continue
				fi
			done
		total="$(echo "${tokens}" | wc -l)"
		available="$(wc -l < ${linode_root_path}/Tokens/valid.txt)"
		echo "共检测${total}个token，有效token${available}个"
	else
		echo -n "正在检测API是否可用："
		if $(curl -H "Content-Type: application/json" -H "Authorization: Bearer $access_token" -X GET  https://api.linode.com/v4/account -s | jq 'has("errors")')
			then
				echo "不可用"
				exit 0
		else
            echo "可用"
		fi
	fi
}

save_api(){
	local choice='y'
	read -p "是否保存API?（默认保存）[y/n]" choice
	if [ "$choice" = "y" -o -z "$choice" ];then
        isExist="false" ##假设API未保存
	    if [ ! -e "${linode_root_path}/Tokens" ] ##判断是否存在文件夹
	    then
	        echo "存储文件夹不存在，即将创建......."
		    mkdir -p ${linode_root_path}/Tokens/valid
			mkdir -p ${linode_root_path}/Tokens/disabled
		    touch ${linode_root_path}/Tokens/all.txt
			touch ${linode_root_path}/Tokens/valid.txt
	    else ##如果存在文件夹，判断是否存在api.txt
	        if [ -e ./data/Linode/Tokens/all.txt ];then
	            for token in $(cat ${linode_root_path}/Tokens/all.txt )
		        do
	                if [ $access_token = $token ];then
			            isExist="true"
				        echo "API已存在，请进行下一步操作"
			            break
			        fi
	            done
		    fi
	    fi
        if [ $isExist = "false" ];then
		        echo $access_token >> ${linode_root_path}/Tokens/all.txt
				echo $access_token >> ${linode_root_path}/Tokens/valid.txt
				mkdir -p ${linode_root_path}/Tokens/valid/${access_token}
				query_account
                save_acc_info
				show_linode "$access_token"
			    echo "API已添加，请进行下一步操作"
	    fi
    elif [ "$choice" = "n" ];then
	    echo "API将不会保存"
	else
	    echo "请输入正确的选项"
		save_api
	fi
}

query_credit(){
	resp=$(curl -H "Authorization: Bearer $access_token" https://api.linode.com/v4/account -s)
	if $(echo $resp | jq 'has("errors")');then
		echo "查询失败,$(echo $resp | jq .errors)"
	else
		credit=$(echo ${resp} | jq -r '{balance, balance_uninvoiced, "credit_remaining": .active_promotions[0].credit_remaining, "credit_expire_dt": .active_promotions[0].expire_dt}')
	fi
}

promo_credit_add(){
	resp=$(curl -H "Content-Type: application/json" -H "Authorization: Bearer $access_token" -X POST -d "{\"promo_code\": \"$promo_code\"}" https://api.linode.com/v4/account/promo-codes -s)
	if $(echo $resp | jq 'has("errors")');then
		echo "添加优惠码失败,$(echo $resp | jq .errors)"
	fi
}

add_promo_credit(){
	read -p "请输入优惠码（留空将自动获取最新优惠码）：" promo_code
	if [ -z $promo_code ];then
		get_promo_code
	fi
	promo_credit_add
	query_credit
	echo "${credit}"
}

## 查询账户信息
## TODO: 优化接口（credit与用户信息使用相同接口）
query_account(){
	query_credit
	resp=$(curl -H "Content-Type: application/json" -H "Authorization: Bearer $access_token" -X GET  https://api.linode.com/v4/account/payment-methods -s)
	payment_method=$(echo $resp | jq -r '{"payment_method": .data[].type}')
	resp=$(curl -H "Content-Type: application/json" -H "Authorization: Bearer $access_token" -X GET  https://api.linode.com/v4/account/users -s)
	username=$(echo $resp | jq -r '.data[] | {username}')
	resp=$(curl -H "Content-Type: application/json" -H "Authorization: Bearer $access_token" -X GET  https://api.linode.com/v4/account -s)
	user_info=$(echo $resp | jq -r '{email, active_since, address_1, address_2, city, state, country, zip}')
	acc_info=$(echo "[${credit},${username},${user_info},${payment_method}]" | jq 'add | [.]')
}

## 输出账户信息
show_account_info(){
	local acc_info=$(cat ${linode_root_path}/Tokens/valid/${access_token}/info.txt)
	json_to_table "$acc_info"
}

## 保存账号信息(以json形式存储)
save_acc_info(){
	if [ -e "${linode_root_path}/Tokens/valid/${access_token}" ]
	then
		echo $acc_info > ${linode_root_path}/Tokens/valid/${access_token}/info.txt
	fi
}

update_credit(){
	if [ -e "${linode_root_path}/Tokens/valid/${access_token}/info.txt" ]
	then
		echo [$(cat "${linode_root_path}/Tokens/valid/${access_token}/info.txt"),$credit] | jq '[.[0].[] + .[1]]' > .temp.txt && mv .temp.txt "${linode_root_path}/Tokens/valid/${access_token}/info.txt"
	fi
}

## 显示账户信息
show_account(){
	query_account
	save_acc_info
	show_linode "$access_token"
	show_account_info
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

	if $(curl -H "Content-Type: application/json" -H "Authorization: Bearer $access_token" -X POST -d "{\"image\": \"linode/$image\",\"root_pass\": \"$password\"}" https://api.linode.com/v4/linode/instances/$id/rebuild -s | jq 'has("errors")');then
		echo "重装失败，请稍后重试"
	else
		echo "密码为$password"
	fi
}


#升级实例
linode_resize(){
	show_linode
	read -p "请输入需要升级的实例ID: " id
	read -p "请输入需要升级的配置:（默认为g6-standard-2）" type

	if [ -z $type ];then
		type=g6-standard-2
	fi

	curl -H "Content-Type: application/json" -H "Authorization: Bearer $access_token" -X POST -d "{\"type\":\"$type\"}" https://api.linode.com/v4/linode/instances/$id/resize
}



#查看实例配置种类
show_types(){
	curl https://api.linode.com/v4/linode/types -s | sed 's/},/\n/g'| grep -E '"id"|"lable" |"memory"|"vcpus"|"gpus"|"cpus"' | awk -F , '{print $1,$2}'| sed 's/{//g'
}

#查询账户内虚拟机
query_linode(){
	instances=$(curl -H "Authorization: Bearer $access_token" https://api.linode.com/v4/linode/instances -s | jq -r '.data | map({id, label, ipv4: .ipv4.[], ipv6, image, region, type, status, created})')
}

show_linode_info(){
	local instance=$(cat ${linode_root_path}/Tokens/valid/${access_token}/vm.txt)
	local number=$(echo "$instances" | jq -r 'length')
	echo -e "$instances \n"
	echo -e "您的账户共有${number}台实例"	
}

save_linode_info(){
	if [ -e "${linode_root_path}/Tokens/valid/${access_token}" ]
	then
		echo $instances > ${linode_root_path}/Tokens/valid/${access_token}/vm.txt
	fi
}

# 函数内部可以共享局部变量（调用函数）
show_linode(){
	if [ -z $1 ];then
		# 创建局部变量用于函数内部共享，保证使用变量名却不影响全局变量
	    local access_token=$access_token 
	else
	    local access_token=$1 # 用于批量更新账号高实例信息
	fi
	
	query_linode
	save_linode_info
	
	if [ -z $1 ];then
	    show_linode_info
	fi
}

#查看实例地区
show_regions(){
	curl https://api.linode.com/v4/linode/region -s
}

#创建虚拟机 地区：
create_linode(){
	while true
	do
				read -p "请选择地区(1.新加坡 2.印尼雅加达 3.日本东京 4.日本大阪 5.印度孟买 6.印度清奈 7.澳大利亚悉尼 8.澳大利亚墨尔本 9.德国法兰克福 10.英国伦敦1区 11.英国伦敦2区 12.法国巴黎 13.瑞典斯德哥尔摩 14.意大利米兰 15.荷兰阿姆斯特丹 16.西班牙马德里 17.加拿大多伦多 18.美国中部德克萨斯州达拉斯 19.美国西部加利福尼亚 20.美国东部新泽西州纽瓦克 21.美国东南部亚特兰大 22.美国芝加哥 23.美国华盛顿 24.美国西雅图 25.美国迈阿密 26.美国洛杉矶 27.巴西圣保罗):" num
		
		if [ ${num} -gt ${#regions[@]} -o ${num} -lt 1 ]; then
			echo -e "${red}\n请输入正确的数字 [1-${#regions[@]}]${plain}"
		else
			region=${regions[${num}-1]}
		fi


		# case "$num" in
			# 1)
			# region=ap-south
			# break
			# ;;
			# 2)
			# region=id-cgk
			# break
			# ;;
			# 3)
			# region=ap-northeast
			# break
			# ;;
			# 4)
			# region=jp-osa
			# break
			# ;;
			# 5)
			# region=ap-west
			# break
			# ;;
			# 6)
			# region=in-maa
			# break
			# ;;
			# 7)
			# region=ap-southeast
			# break
			# ;;
			# 8)
			# region=eu-central
			# break
			# ;;
			# 9)
			# region=eu-west
			# break
			# ;;
			# 10)
			# region=fr-par
			# break
			# ;;
			# 11)
			# region=se-sto
			# break
			# ;;
			# 12)
			# region=it-mil
			# break
			# ;;
			# 13)
			# region=nl-ams
			# break
			# ;;
			# 14)
			# region=es-mad
			# break
			# ;;
			# 15)
			# region=ca-central
			# break
			# ;;
			# 16)
			# region=us-central
			# break
			# ;;
			# 17)
			# region=us-west
			# break
			# ;;
			# 18)
			# region=us-east
			# break
			# ;;
			# 19)
			# region=us-southeast
			# break
			# ;;
			# 20)
			# region=us-ord
			# break
			# ;;
			# 21)
			# region=us-iad
			# break
			# ;;
			# 22)
			# region=us-sea
			# break
			# ;;
			# 23)
			# region=us-mia
			# break
			# ;;
			# 24)
			# region=us-lax
			# break
			# ;;
			# 25)
			# region=br-gru
			# break
			# ;;
			# *) echo -e "${red}\n请输入正确的数字 [1-18]${plain}"
			# ;;
		# esac
	done

	read -p "请输入root密码: （留空则生成随机密码）" password
	read -p "请输入标签: （可以留空）" label
	read -p "请输入系统: （默认为debian10）" image
	read -p "请输入实例配置: （默认为g6-nanode-1）" type
	read -p "请输入创建数量: （默认为1）" count
	read -p "是否检测被墙: （默认不检测）[y/n]" choice


	# 默认值
	if [ -z $password ]
	then
		local genpw=1
		local password=$(randpw)
	fi
	local image=${image:-debian11}
	local type=${type:-g6-nanode-1}
	local count=${count:-1}
	local choice=${choice:-n}


	while [ $count -gt 0 ]
	do
		local flag=2
		if [ $genpw -eq 1 ]
		then
			password=$(randpw)
		fi
		resp=$(curl -X POST https://api.linode.com/v4/linode/instances -H "Authorization: Bearer $access_token" -H "Content-type: application/json" -d "{\"type\": \"$type\", \"region\": \"$region\", \"image\": \"linode/$image\", \"root_pass\": \"$password\", \"label\":\"$label\"}" -s)
		if $(echo $resp | jq 'has("errors")');then
			echo -e "创建实例失败，请查看下方原因后重试"
			echo $resp | jq -r '.errors[] | values'
		fi

		if [ $flag -eq 0 ];then
			continue
		fi

		info=$(echo ${resp} | jq -r '[{id, label, ipv4: .ipv4.[], ipv6, image, region, type}]')
		echo $info | jq .[]
		echo -E "密码为${password}"
		echo [$(cat "${linode_root_path}/Tokens/valid/${access_token}/vm.txt"),$info] | jq 'add' > .temp.txt && mv .temp.txt "${linode_root_path}/Tokens/valid/${access_token}/vm.txt"
		count=$((count-1))
	done
}

# https://www.linode.com/docs/guides/rescue-and-rebuild/

#删除虚拟机
delete_linode(){
	if [ $# -eq 0 ]; then
		show_linode
		read -p "请输入需要删除的虚拟机ID: " id
    else
		id=$1
    fi

	resp=$(curl -H "Authorization: Bearer $access_token" -X DELETE https://api.linode.com/v4/linode/instances/$id -s)
	if $(echo $resp | jq 'has("errors")');then
		echo "删除失败,$(echo $resp | jq -r '.errors')"
	else
		jq -r --arg id "$id" '. - [.[] | select(.id == ($id | tonumber))]' "${linode_root_path}/Tokens/valid/${access_token}/vm.txt" > .temp.txt && mv .temp.txt "${linode_root_path}/Tokens/valid/${access_token}/vm.txt"
		echo "删除成功"
	fi
}

search_linode(){
	local dir=${linode_root_path}/Tokens/${1}
	for token in $(ls "$dir")
	do
		local path="${dir}/${token}"
		if [ -d "${path}" ]
		then
			local result=$(jq -r --arg IP "$IP" 'map(select(.ipv4 == $IP)) | length' "$path/vm.txt")
			# echo $result
			if [ $result -eq 0 ];then
				continue
			else
				isFound=1
				access_token=$token
				show_linode
				echo -e "该实例所在账号API为${access_token}"
				break
			fi
		fi
	done
}

find_linode(){
	read -p "请输入需要查找的实例IP:" IP
	echo "正在进行本地查找，请稍等"
	echo "正在查找有效账号"
	local isFound=0
	
	search_linode "valid"

	if [ $isFound -eq 0 ];then
		echo "该实例不存在于本地有效账号实例列表中，准备查找失效账号！"
		search_linode "disabled"

		if [ $isFound -eq 0 ];then
			echo -e "该实例不属于已知本地账号！准备进行在线查找"
			for token in $(cat "${linode_root_path}/Tokens/valid.txt");do
				show_linode "$token"
			done
			
			search_linode "valid"
			
			if [ $isFound -eq 0 ];then
				echo "该实例不属于已知账号！请检查后重试！"
			fi
		else
			echo "，账号已失效"
		fi
	fi
}

show_menu(){
	while true
	do
		echo -e  "
  ${green}linode 管理脚本${plain}
—————————————————————
  ${green} 0.${plain} 退出脚本

————— 账号相关 ——————

  ${green} 1.${plain} 账号信息
  ${green} 2.${plain} 添加优惠码
  ${green} 3.${plain} 检测API

————— 实例相关 ——————

  ${green} 4.${plain} 创建实例
  ${green} 5.${plain} 删除实例
  ${green} 6.${plain} 查看实例
  ${green} 7.${plain} 重置密码
  ${green} 8.${plain} 搜寻实例
  ${green} 9.${plain} 重装实例
  ${green}10.${plain} 重启实例
  ${green}11.${plain} 升级实例

—————————————————————
 "
		echo && read -p "请输入选择 [0-8]: " num
		case "$num" in
			0)exit 0
			;;
			1)show_account
			is_continue
			;;
			2)add_promo_credit
			is_continue
			;;
			3)check_api
			is_continue
			;;
			4)create_linode
			is_continue
			;;
			5)delete_linode
			is_continue
			;;
			6)show_linode
			is_continue
			;;
			7)reset_password
			is_continue
			;;
			8)find_linode
			is_continue
			;;
			9)linode_rebuild
			is_continue
			;;
			10)reboot_linode
			is_continue
			;;
			11)linode_resize
			is_continue
			;;
			*) echo -e "${red}\n请输入正确的数字 [0-11]${plain}" && show_menu
			;;
		esac
	done
}


##主进程
check_api 1 ##使用脚本即对API可用性进行检查
check_dependencies "jq"
save_api ##保存可用API
show_menu
