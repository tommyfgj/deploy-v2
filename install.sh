#! /bin/bash

if [ $# != 2 ];then
    echo "Usage:bash install.sh [server_name] [uuid]"
    exit 1
fi

SERVERNAME=$1
UUID=$2
OPENFILES=204800

#check ubuntu version...
cat /etc/issue |grep "Ubuntu 16.04">/dev/null
if [ $? -ne 0 ];then
    echo 'The version of system is not Ubuntu 16.04, exit...'
    exit 1
fi

#initialize machine env...
ulimit -n ${OPENFILES}
mkdir -p /root/v2ray/
mkdir -p /root/caddy/

#install docker and git...
sudo apt-get install -y docker docker.io && sudo apt-get install -y git && sudo apt-get install -y curl
if [ $? -ne 0 ];then
    echo 'install docker or git fail...'
    exit 1
fi

#clone configs and initializing...
rm -rf /tmp/deploy-v2
cd /tmp && git clone https://github.com/tommyfgj/deploy-v2.git
if [ $? -ne 0 ];then
    echo 'git clone https://github.com/tommyfgj/deploy-v2.git fail...'
    exit 1
fi

cd /tmp/deploy-v2/configs/
cp -r caddy/* /root/caddy/
cp -r v2ray/* /root/v2ray/

cd /root/caddy/ && sed -i "s/{{server_name}}/${SERVERNAME}/g" Caddyfile && cd /root/v2ray/conf && sed -i "s/{{UUID}}/${UUID}/g" config.json
if [ $? -ne 0 ];then
    echo 'initialize config fail...'
    exit 1
fi

#pull docker images
docker rm -f $(docker ps -a -q)
docker rmi $(docker images | grep -v "IMAGE" | awk '{print $3}')
docker pull abiosoft/caddy && docker pull v2ray/official
if [ $? -ne 0 ];then
    echo 'pull images fail...'
    exit 1
fi

#create docker subnet
docker network rm mynetwork
docker network create --subnet=172.18.0.0/16 mynetwork
if [ $? -ne 0 ];then
    echo 'create docker subnet fail...'
    exit 1
fi

#create docker container
docker run -d \
    -v /root/caddy/Caddyfile:/etc/Caddyfile \
    -v /root/caddy/.caddy:/root/.caddy \
    -v /root/caddy/html:/html \
    -v /root/caddy/log:/var/log/caddy \
    -p 80:80 -p 443:443 \
    --net mynetwork --ip 172.18.0.2 \
    abiosoft/caddy
if [ $? -ne 0 ];then
    echo 'run caddy fail...'
    exit 1
fi

docker run -d  --net mynetwork --ip 172.18.0.3 -v /root/v2ray/conf:/etc/v2ray -v /root/v2ray/log:/var/log/v2ray -p 172.18.0.1:8085:8085 v2ray/official  v2ray -config=/etc/v2ray/config.json
if [ $? -ne 0 ];then
    echo 'run v2ray fail...'
    exit 1
fi

#test network
curl "https://${SERVERNAME}/mail"|grep -i 'bad request' > /dev/null
if [ $? -ne 0 ];then
    echo 'test v2ray network fail...'
    exit 1
fi

echo "install caddy & v2ray successfully..."





