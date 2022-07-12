#!/bin/bash
#set -xv
file="./api.txt"
access_token=$1
regions=("ap-south" "ap-northeast" "ap-west" "ap-southeast" "eu-central" "eu-west" "ca-central" "us-central" "us-west" "us-east" "us-southeast")

#生成随机密码
randpw(){
	</dev/urandom tr -dc '12345qwertQWERTasdfgASDFGzxcvbZXCVB' | head -c12
}


#创建虚拟机 地区：
create_linode(){	
	password=R1g2xeba4DcE
	image=centos7
	type=g6-nanode-1
	region=${regions[`expr $RANDOM % 11`]}
	
	unsolvedip=$(curl -X POST https://api.linode.com/v4/linode/instances -H "Authorization: Bearer $access_token" -H "Content-type: application/json" -d "{\"type\": \"$type\", \"region\": \"$region\", \"image\": \"linode/$image\", \"root_pass\": \"$password\", \"label\":\"$label\"}" -s |sed 's/,/\n/g'| grep ipv4)
	
	
	echo -E "${unsolvedip:11:`expr ${#unsolvedip}-13`} ${password}" >> "./ip.txt"
}

# https://www.linode.com/docs/guides/rescue-and-rebuild/

		
create_linode

