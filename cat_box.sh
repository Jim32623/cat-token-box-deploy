#!/bin/bash

# 一键部署脚本 - CAT Protocol on Fractal Mainnet

# 更新系统
echo "更新系统..."
sudo apt-get update && sudo apt-get upgrade -y

# 安装 Docker
echo "安装 Docker..."
sudo apt-get install docker.io -y

# 安装最新版本的 docker-compose
echo "安装 docker-compose..."
VERSION=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d')
DESTINATION=/usr/local/bin/docker-compose
sudo curl -L https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s)-$(uname -m) -o $DESTINATION
sudo chmod 755 $DESTINATION

# 安装 Node.js 和 npm
echo "安装 Node.js 和 npm..."
sudo apt-get install npm -y
sudo npm install n -g
sudo n stable

# 安装 yarn
echo "安装 yarn..."
sudo npm i -g yarn

# 拉取 Git 仓库
echo "拉取 Git 仓库..."
git clone https://github.com/CATProtocol/cat-token-box
cd cat-token-box

# 安装依赖并编译
echo "安装依赖并编译项目..."
sudo yarn install
sudo yarn build

# 运行 Docker 容器
echo "运行 Fractal 节点..."
cd ./packages/tracker/
sudo chmod 777 docker/data
sudo chmod 777 docker/pgdata
sudo docker-compose up -d

# 返回项目根目录并构建 Docker 镜像
cd ../../
sudo docker build -t tracker:latest .

# 运行本地索引器
echo "运行本地索引器..."
sudo docker run -d \
    --name tracker \
    --add-host="host.docker.internal:host-gateway" \
    -e DATABASE_HOST="host.docker.internal" \
    -e RPC_HOST="host.docker.internal" \
    -p 3000:3000 \
    tracker:latest

# 创建钱包
echo "创建钱包..."
cd packages/cli

# 创建 config.json 文件并添加配置信息
echo "创建 config.json 文件..."
cat <<EOL > config.json
{
  "network": "fractal-mainnet",
  "tracker": "http://127.0.0.1:3000",
  "dataDir": ".",
  "maxFeeRate": 100,
  "rpc": {
      "url": "http://127.0.0.1:8332",
      "username": "bitcoin",
      "password": "opcatAwesome"
  }
}
EOL

# 创建新钱包
sudo yarn cli wallet create

# 提示用户创建完成
echo "钱包创建成功，请记住助记词！"

# 创建重复铸造的脚本
echo "创建重复铸造脚本..."
cat <<EOL > script.sh
#!/bin/bash

command="sudo yarn cli mint -i 45ee725c2c5993b3e4d308842d87e973bf1951f5f7a804b21e4dd964ecd12d6b_0 5"

while true; do
    \$command

    if [ \$? -ne 0 ]; then
        echo "命令执行失败，退出循环"
        exit 1
    fi

    sleep 1
done
EOL

# 给予脚本执行权限
chmod +x script.sh

# 使用 screen 启动 script.sh 脚本
echo "在后台运行 mint 脚本..."
screen -S mint_session -dm ./script.sh

# 提示用户 screen 会话已启动
echo "Screen 会话 'mint_session' 已启动，您可以随时通过 'screen -r mint_session' 连接到该会话。"
echo "如果要退出会话但保持脚本运行，按 Ctrl+A 然后按 D。"

# 脚本结束
echo "部署完成！"
