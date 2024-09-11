#!/bin/bash

# 添加颜色支持
GREEN='\e[1;32m'
CYAN='\e[1;36m'
YELLOW='\e[1;33m'
NC='\e[0m' # 重置颜色

# 显示装饰性标题和说明
echo -e "${CYAN}*********************************************${NC}"
echo -e "${CYAN}**         CAT Token Box Installer         **${NC}"
echo -e "${CYAN}**  自动安装并启动 Fractal 主网节点和铸造工具 **${NC}"
echo -e "${CYAN}*********************************************${NC}"
echo ""
echo -e "${YELLOW}欢迎使用 CAT Token Box 自动部署脚本${NC}"
echo "1，该脚本将帮助您快速安装和配置必要的工具，包括 Docker、Node.js、yarn 等。"
echo "2，您可以选择重启铸造窗口以继续操作。"
echo "特别鸣谢：----YIMING----RUN----"
echo ""
echo -e "${GREEN}请选择一个功能：${NC}"

# 功能菜单
echo "1) 一键安装（包含开启窗口进行重复铸造）"
echo "2) 重启已开启的重复铸造窗口"
read -p "请输入选项编号: " option

case $option in
    1)
        echo -e "${GREEN}开始一键安装...${NC}"

        # 一键安装过程
        echo "更新系统..."
        sudo apt-get update && sudo apt-get upgrade -y

        echo "安装 Docker..."
        sudo apt-get install docker.io -y

        echo "安装 docker-compose..."
        VERSION=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d')
        DESTINATION=/usr/local/bin/docker-compose
        sudo curl -L https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s)-$(uname -m) -o $DESTINATION
        sudo chmod 755 $DESTINATION

        echo "安装 Node.js 和 npm..."
        sudo apt-get install npm -y
        sudo npm install n -g
        sudo n stable

        echo "安装 yarn..."
        sudo npm i -g yarn

        echo "拉取 Git 仓库..."
        git clone https://github.com/CATProtocol/cat-token-box
        cd cat-token-box

        echo "安装依赖并编译项目..."
        sudo yarn install
        sudo yarn build

        echo "构建 Docker 镜像..."
        cd ./packages/tracker/
        sudo chmod 777 docker/data
        sudo chmod 777 docker/pgdata
        sudo docker build -t tracker:latest .   # 本地构建镜像，避免拉取失败

        echo "运行 Fractal 节点..."
        sudo docker-compose up -d

        cd ../../
        sudo docker build -t tracker:latest .

        echo "运行本地索引器..."
        sudo docker run -d \
            --name tracker \
            --add-host="host.docker.internal:host-gateway" \
            -e DATABASE_HOST="host.docker.internal" \
            -e RPC_HOST="host.docker.internal" \
            -p 3000:3000 \
            tracker:latest

        echo "创建钱包..."
        cd packages/cli

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

        sudo yarn cli wallet create

        read -p "请确认您已保存好钱包助记词，然后按任意键继续..."

        echo "钱包创建成功，请记住助记词！"

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

        chmod +x script.sh

        echo "在后台运行 mint 铸造脚本..."
        screen -S mint_session -dm ./script.sh

        echo "Screen 会话 'mint_session' 已启动，您可以随时通过 'screen -r mint_session' 连接到该会话。"
        echo "如果要退出会话但保持脚本运行，按 Ctrl+A 然后按 D。"

        echo -e "${GREEN}一键安装和铸造操作完成！${NC}"
        ;;
    2)
        echo "重启铸造窗口..."

        cd "$HOME/cat-token-box/packages/cli"
        screen -S mint_session -dm ./script.sh
        echo "铸造窗口已重启。"
        ;;
    *)
        echo -e "${RED}无效的选项。请重新运行脚本并选择一个有效的选项。${NC}"
        ;;
esac
