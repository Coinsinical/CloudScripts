# CloudScripts
A good way to use shell scripts to manage your linodes

## 功能
- API检测
- 账户信息获取并存储
- 添加优惠码
- 创建实例（批量/单独）
- 删除实例
- 查看账户下实例详细信息
- 重置实例密码
- 根据IP搜索实例（切换至所在账号）
- 重装实例
- 重启实例
- 实例配置升级

## TODO:
- [] 添加工单提配额功能

## 使用方法
1. git clone 本仓库至本地
2. 运行脚本
   ```shell
   bash linode.sh <token>
   ```
### 注意： 脚本强依赖于jq库，使用前请确保系统已安装该软件包，安装方法请自行搜索。
