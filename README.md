# Linode_scripts
A good way to use shell scripts to manage your linodes

# 文件结构
 CloudSripts
 │
 ├─linode.sh
 │
 └─data
     └─Linode
         │-regions.txt
         │
         └─Tokens
             ├─all.txt
             ├─valid.txt
             │
             ├─disabled
             │  └─disabled_example_token
             │          ├─info.txt
             │          └─vm.txt
             │
             └─valid
                 └─valid_example_token
                         ├─info.txt
                         └─vm.txt

# TODO:
- [] 添加工单提配额功能

# 使用方法
1. git clone 本仓库至本地
2. 运行脚本
   ``` bash linode.sh <token> ```
