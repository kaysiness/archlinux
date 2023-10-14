# 創建容器
``` shell
sudo pacman -S arch-install-scripts
sudo mkdir -p /var/lib/machines/gateway

# 給容器安裝base包和一些常用軟件包
sudo pacstrap -i -c /var/lib/machines/gateway base neovim

# 由於ArchLinux默認root沒有密碼，需要先進入容器設置密碼
sudo systemd-nspawn -D /var/lib/machines/gateway
passwd

# 如果提示`Login incorrect`，這是因爲容器的`/etc/securetty`安全配置導致。
vi /etc/securetty

# 在檔案底部新增以下兩行
pts/0  
pts/1

# 登出
logout
```

# 創建.nspawn設定檔
```systemd
# vi /etc/systemd/nspawn/gateway.nspawn

[Exec]
Hostname=gateway
Timezone=Asia/Hong_Kong
Capability=CAP_NET_ADMIN CAP_NET_RAW
#Capability=CAP_SYS_MODULE CAP_NET_ADMIN
#Capability=all

[Files]
#TemporaryFileSystem=/tmp
Bind=/lib/firmware
Bind=/var/cache/pacman/pkg
BindReadOnly=/home/kaysiness/.cache/yay:/aur
BindReadOnly=/etc/environment
BindReadOnly=/etc/pacman.conf
BindReadOnly=/etc/pacman.d/mirrorlist

[Network]
#Private=yes
MACVLAN=end0    # 改爲宿主機的網卡名字
```

# 啓動容器
```shell
# 正常啓動容器
sudo machinectl start gateway
sudo machinectl login gateway

# 設定Network
# vi /etc/systemd/network/20-mv-end0.network
[Match]
Name=mv-end0

[Network]
Address=10.0.0.150/24
Gateway=10.0.0.1
DNS=10.0.0.1

# 啓動網絡
systemctl enable --now systemd-networkd.service systemd-resolved.service
```

# 設置開機自動啓動gateway容器
```
sudo machinectl enable gateway
```

# 參考
* [Archlinux Wiki](https://wiki.archlinux.org/title/Systemd-nspawn)
* [manpage](https://man.archlinux.org/man/systemd.nspawn.5)