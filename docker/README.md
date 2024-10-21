記錄下自己安裝和設定Docker的過程，基於`Docker version 27.3.1, build ce1223035a`和`Docker Compose version 2.29.7`。

<!--more-->

# 安裝與設定
```bash
yay -S docker docker-compose
```

## 打開IPv6支持
創建`/etc/docker/daemon.json`文件，寫入以下內容
```json
{
  "ipv6": true,
  "fixed-cidr-v6": "fc00:10:172:17::/64",
  "ip6tables": true,
  "experimental": true
}
```
不過我其實是禁用了默認briger網絡的
```json
{
  "bridge": "none",
  "ip6tables": true,
  "experimental": true
}
```

## 啓動服務
```bash
sudo systemctl enable --now docker.service
```

# 創建給容器用的Bridge網絡
用於替換默認的default bridge網絡，因爲默認的網絡不能手動指定容器的IP地址
```bash
sudo docker network create \
  --subnet=10.10.101.0/24 \
  --gateway=10.10.101.1 \
  --ipv6 \
  --subnet=fc00:10::/64 \
  --gateway=fc00:10::101:0 \
  --ip-range=fc00:10::101:0/112 \
  --opt com.docker.network.bridge.name=docker1 \
  --opt com.docker.network.bridge.host_binding_ipv4=0.0.0.0 \
  --opt com.docker.network.driver.mtu=1500 \
  home-br
```

# 创建给容器用的Macvlan网络
## 注意事項
1. 只要DHCPv6/SLAAC正常的話，加入網絡的容器也能獲取到公網IPv6地址
2. 容器對局域網內其他主機提供服務的話，macvlan按理說比端口映射性能好
3. 只要在網關OpenWrt上設置好防火牆，外界是不能通過公網IPv6訪問到容器的
4. 宿主機訪問容器需要特別處理，後面會說到

## 手動創建Macvlan網絡
```bash
sudo docker network create \
  -d macvlan \
  --subnet=10.0.0.0/16 \
  --gateway=10.0.0.1 \
  --ip-range=10.0.101.0/24 \
  --aux-address="area=10.0.101.0" \
  --aux-address="gateway=10.0.101.1" \
  --ipv6 \
  --subnet=fc00::/64 \
  --gateway=fc00::1 \
  --ip-range=fc00::101:0/112 \
  --aux-address="area=fc00::101:0" \
  --aux-address="gateway=fc00::101:1" \
  -o parent=enp1s0 \
  home-lan
```
※ `--aux-address=`不寫也沒關係，作用是給容器自動分配IP時會排除掉aux-address指定的IP

## 容器加入macvlan網絡並指定IP地址的方法
```yaml
services:
  service_name:
    networks:
      home-lan:
        ipv4_address: 10.0.101.50
        ipv6_address: fc00::101:50
        aliases:  # 別名不寫也沒關係
          - service_name.lan

networks:
  home-lan:
    external: true
```

## 解決宿主機無法訪問容器的問題
其原理是，因爲macvtap網卡之間是可以正常通訊的，那麼只要給宿主機添加一個macvtap網卡即可訪問到容器

### 創建自動添加macvtap網卡的bash腳本
※ 別忘記給腳本添加執行權限和enable timer

* [/etc/systemd/system/macvtap-host.service](/docker/systemd/macvtap-host.service)
* [/etc/systemd/system/macvtap-host.timer](/docker/systemd/macvtap-host.timer)
* [/usr/local/bin/macvtap.sh](/docker/bin/macvtap.sh)


## 使用nginx-proxy自動給容器服務做反代
應該沒人喜歡通過`ip:port`來訪問容器服務的，而且每個加入home-lan的容器IP也不可能全部記住，那麼使用Nginx來做服務反代就很有必要了
在自動反代服務上有很多選擇，比如`Nginx Proxy Manager`和`Traefik`，我選擇 https://github.com/nginx-proxy/nginx-proxy 來實現，因爲後者簡單方便

### 注意事項
1. 需要一個域名，下文使用`docker.kkun.date`這個域名來演示，使用`srv1.docker.kkun.date`來訪問srv1容器，以此類推
2. 通過acme.sh給`*.docker.kkun.date`域名申請SSL證書，不申請也可以但現代瀏覽器會提示http不安全
3. 最好有一個本地DNS，把`*.docker.kkun.date`解析到`nginx-proxy`容器的IP地址

### 啓動`acme.sh`和`nginx-proxy`容器
* [docker-compose.yml](/docker/docker-compose/nginx-proxy.yml)

### 申請SSL證書
```bash
# 申請證書
sudo docker exec acme.sh --register-account -m <email>
sudo docker exec acme.sh --issue --dns dns_cf -k ec-256 -d "*.docker.kkun.date"

# 把證書的crt和key複製到certs volume中
# 注意證書的名字，否則nginx-proxy容器會無法讀取到證書
# 比如泛域名「*.docker.kkun.date」需要寫成「docker.kkun.date.crt」和「docker.kkun.date.key」
sudo docker exec acme.sh --install-cert --ecc -d "*.docker.kkun.date" --key-file /certs/docker.kkun.date.key --fullchain-file /certs/docker.kkun.date.crt

# 證書續期，一般acme.sh會自動續期，只需要設置一個systemd.path服務監控證書變化並重啓nginx-proxy容器即可
sudo docker exec acme.sh --renew --dns dns_cf --ecc -d "*.docker.kkun.date"

# 吊銷證書
sudo docker exec acme.sh --revoke --ecc -d "*.docker.kkun.date"
```

### 監控證書變化並自動重啓nginx-proxy容器
* [/usr/local/bin/certs-renew.sh](/docker/bin/certs-renew.sh)
* [/etc/systemd/system/certs-renew.service](/docker/systemd/certs-renew.service)
* [/etc/systemd/system/certs-renew.path](/docker/systemd/certs-renew.path)


### 給容器綁定域名
通過給容器添加`VIRTUAL_HOST`和`VIRTUAL_PORT`環境變量，並指定域名和端口號即可

以下是一個簡單的例子
```yaml
services:
  srv1:
    environment:
      VIRTUAL_HOST: srv1.docker.kkun.date
      VIRTUAL_PORT: 80
      VIRTUAL_PATH: /
      VIRTUAL_DEST: /
    expose:
      - 80
```

給容器綁定多個域名
```yaml
services:
  srv1:
    environment:
      VIRTUAL_HOST_MULTIPORTS: |-
        srv1.docker.kkun.date:
          "/":
            port: "80"
            dest: "/"
        srv2.docker.kkun.date:
          "/api/":
            port: "81"
            dest: "/api/"
    expose:
      - 80
      - 81
```


### docker-compose.yml 完整演示例子
```yaml
services:
  syncthing:
    container_name: syncthing
    image: linuxserver/syncthing:latest
    restart: unless-stopped
    environment:
      PUID: 1000
      PGID: 1000
      VIRTUAL_HOST: share.docker.kkun.date
      VIRTUAL_PORT: 8384
      VIRTUAL_PATH: /sync/
      VIRTUAL_DEST: /
    volumes:
      - config:/config
      - ./Sync:/config/Sync
    networks:
      home-lan:
        ipv4_address: 10.0.101.50
        ipv6_address: fc00::101:50
        aliases:
          - syncthing.lan
    expose:
      - 8384
      - 22000
      - 21027

networks:
  home-lan:
    external: true

volumes:
  config:
```
當容器跑起來後，就能在瀏覽器通過`https://share.docker.kkun.date/sync/`訪問到syncthing容器