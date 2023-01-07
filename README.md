- [安裝基本系統](#安裝基本系統)
  - [硬盤分區](#硬盤分區)
  - [安裝系統](#安裝系統)
  - [安裝GRUB](#安裝grub)
  - [重啓前的準備](#重啓前的準備)
    - [新建普通用戶](#新建普通用戶)
    - [讓普通用戶使用sudo](#讓普通用戶使用sudo)
    - [啓用NTP矯時](#啓用ntp矯時)
    - [更換源](#更換源)
- [安裝桌面環境](#安裝桌面環境)
  - [安裝Xorg和顯卡驅動](#安裝xorg和顯卡驅動)
  - [PipeWire](#pipewire)
  - [NetworkManager](#networkmanager)
  - [字體](#字體)
  - [安裝KDE](#安裝kde)
  - [輸入法Fcitx](#輸入法fcitx)
- [配置桌面環境](#配置桌面環境)
  - [創建家目錄下的默認目錄](#創建家目錄下的默認目錄)
  - [環境變量](#環境變量)
  - [HiDPI](#hidpi)
  - [Firefox相關](#firefox相關)
    - [使用systemd啓動Firefox](#使用systemd啓動firefox)
- [Zsh](#zsh)
- [Docker](#docker)
  - [创建给容器用的Macvlan网络](#创建给容器用的macvlan网络)
  - [OneDrive](#onedrive)
  - [Jellyfin](#jellyfin)
- [Flatpak](#flatpak)
  - [解決字體問題](#解決字體問題)
  - [其他各種會用到的軟件](#其他各種會用到的軟件)
    - [XnViewMP](#xnviewmp)
    - [Jellyfin Media Player](#jellyfin-media-player)
- [常用軟件](#常用軟件)
- [遊戲相關](#遊戲相關)
  - [Steam](#steam)
  - [顯卡直通給Windows Guest虛擬機](#顯卡直通給windows-guest虛擬機)
    - [前期準備](#前期準備)
      - [找出並記下IOMMU分組](#找出並記下iommu分組)
    - [隔離GPU](#隔離gpu)
    - [安裝必要軟體](#安裝必要軟體)
    - [安裝Windows 10](#安裝windows-10)
    - [修改Windows 10的虛擬設定](#修改windows-10的虛擬設定)

---

# 安裝基本系統
參照官方[Wiki](https://wiki.archlinux.org/title/Installation_guide)。

## 硬盤分區
因爲使用的是EUFI+GPT分區，在使用`fdisk`分區時需要將一個至少500MB大小的分區設成`EFI System`類型。以下稱爲esp分區。
```sh
# 格式化esp分區
mkfs.fat -F 32 -n BOOT /dev/nvme0n1p1

# 根分區。-n 32k指定node size，默認是16K。
mkfs.btrfs -L ROOT -n 32k /dev/nvme0n1p2

# 掛載根分區到/mnt時，增加使用透明壓縮項
mount -o compress=zstd /dev/nvme0n1p2 /mnt

# 掛載esp分區，我喜歡掛載爲/boot
mkdir /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot
```

## 安裝系統
```sh
pacstrap /mnt base linux-lts linux-firmware btrfs-progs grub efibootmgr sudo vim nano
```

## 安裝GRUB
```sh
vim /etc/default/grub
# 等待時間
GRUB_TIMEOUT=0
```
※ 如需要發現其他硬盤上的Windows系統，可以參考這篇[Wiki](https://wiki.archlinux.org/title/GRUB#Windows_installed_in_UEFI/GPT_mode)。直接把生成的內容寫入`/etc/grub.d/40_custom`末尾。


```sh
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
```

## 重啓前的準備

### 新建普通用戶
```sh
useradd -m -G wheel -s /bin/bash kaysiness
passwd kaysiness
```

### 讓普通用戶使用sudo
* https://wiki.archlinux.org/title/Sudo
```sh
env EDITOR=/usr/bin/vim visudo
```
```apache
# Reset environment by default
Defaults      env_reset
# Set default EDITOR to restricted version of nano, and do not allow visudo to use EDITOR/VISUAL.
Defaults      editor=/usr/bin/vim, !env_editor

kaysiness     ALL=(ALL:ALL) ALL
kaysiness     ALL=NOPASSWD: /usr/bin/pacman,/usr/bin/yay
```

### 啓用NTP矯時
```sh
timedatactl set-ntp true
```

### 更換源
```sh
vim /etc/pacman.d/mirrorlist
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch

vim /etc/pacman.conf
# 把Color前的註釋去掉，讓Pacman可以彩色輸出
[archlinuxcn]
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/$arch

pacman -Syy archlinuxcn-keyring yay
```

※ `yay`位於`archlinuxcn`源裏，不启用的話就只能通過[AUR](https://aur.archlinux.org/packages/yay)安裝了。

然後就能重啓進入Archlinux了。


# 安裝桌面環境

此處用的是`AMD Ryzen5 3400G`自帶的核顯

## 安裝Xorg和顯卡驅動
參考
* https://wiki.archlinux.org/title/Xorg
* https://wiki.archlinux.org/title/AMDGPU
```sh
yay -S xorg-server xf86-video-amdgpu \
       mesa-vdpau \
       vulkan-radeon
```

## PipeWire
```sh
yay -S pipewire pipewire-alsa pipewire-pulse
sudo systemctl enable pipewire-pulse.socket
systemctl --user enable pipewire-pulse.service
```

## NetworkManager
```sh
yay -S networkmanager
sudo systemctl enable NetworkManager.service

# 如果有用其他網絡管理，需要禁用掉
sudo systemctl disable systemd-networkd.service systemd-resolved.service
```

## 字體
```sh
yay -S ttf-dejavu \
       noto-fonts-cjk noto-fonts-emoji noto-fonts \
       wqy-microhei \
       ttf-sarasa-gothic
```

## 安裝KDE
參考
* https://wiki.archlinux.org/title/KDE

注意事項
* `phonon`後端使用`GStreamer`
* `plasma-pa`和`plasma-nm`用於PulseAudio和NetworkManager的組件
* `powerdevil`電源管理。如果不用NetworkManager的話可以裝AUR裏的[`powerdevil-light`](https://aur.archlinux.org/packages/powerdevil-light)
```sh
yay -S plasma-meta kde-applications-meta \
       plasma-pa plasma-nm \
       sddm sddm-kcm \
       kde-gtk-config breeze-gtk \
       powerdevil
               
sudo systemctl enable sddm.service
```

## 輸入法Fcitx
* https://wiki.archlinux.org/title/Fcitx5_(%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87)
* [Rime設定](https://github.com/wongdean/rime-settings)
```sh
yay -S fcitx5-im fcitx5-rime fcitx5-mozc
```
※ System Settings > Regional Settings > Input Method > Configure addons > 「經典用戶界面」旁邊的設置圖標 > 修改「字體」/「垂直候選列表」等，可以改變打字時選字的界面。

# 配置桌面環境

## 創建家目錄下的默認目錄
```sh
yay -S xdg-user-dirs
LC_ALL=C xdg-user-dirs-update --force   # 使用英文名字創建
```

## 環境變量
KDE圖形環境自身使用的環境變量存放在`~/.config/plasma-workspace/env/`下。
* [hidpi.sh](environment/hidpi.sh)
* [firefox.sh](environment/firefox.sh)

※ 可以使用`systemctl --user show-environment`來檢查是否生效。

btw，臨時設置一個圖形環境可用的環境變量，可以用`systemctl --user set-environment <env>=<value>`

## HiDPI
* https://wiki.archlinux.org/title/HiDPI#KDE_Plasma

把`Force fonts DPI`改成`144`。等效於Windows下的150%縮放。

※ 更多的HiDPI設置在上一章節的環境變量中。

## Firefox相關
```sh
yay -S firefox firefox-i18n-zh-tw
firefox -P
```
讓Firefox和KDE集成
* https://wiki.archlinux.org/title/Firefox#KDE_integration

### 使用systemd啓動Firefox
因爲有在同時使用多個profile，使用systemd可以方便的啓動不同profile。
```sh
systemctl edit --user --force --full firefox@.service
```
```ini
[Unit]
Description=Start firefox with the specified profile
PartOf=graphical.target

[Service]
Environment=GTK_USE_PORTAL=1
Type=simple
ExecStart=/usr/bin/firefox -P "%i"

[Install]
WantedBy=multi-user.target
```
啓動指定的profile
```
systemctl start --user firefox@kaysiness.main
```


# [Zsh](https://wiki.archlinux.org/title/Zsh)
```sh
yay -S zsh zsh-completions grml-zsh-config
```
直接抄安裝嚮導的[.zshrc](zsh/zshrc)，方便快捷🙃


# Docker
```sh
yay -S docker docker-compose
sudo systemctl enable docker.service
```
※ 我個人比較喜歡把Docker的各種容器配置文件放在`/docker`下。
```sh
sudo mkdir /docker
```

## 创建给容器用的Macvlan网络
```sh
sudo docker network create -d macvlan --subnet=10.0.0.0/24 --gateway=10.0.0.2 --aux-address="router=10.0.0.1" -o parent=enp5s0 home

# --subnet=10.0.0.0/24  使新建的Macvlan网段和真实局域网段相同
# --gateway=10.0.0.2    网关
# --aux-address=""      让DHCP不分配的IP地址，可以设置多个--aux-address=""，但我的建议是加入这个home网络的容器全部分配静态IP地址。
```

※ 加入home网络的容器手动指定IP地址
```yml
version: "3.6"
services:
  service_name:
    environment:
      - 'ServerIP=10.0.0.50'
    networks:
      home:
        ipv4_address: 10.0.0.50

networks:
  home:
    external: true
    name: home
```

## OneDrive
* https://github.com/abraunegg/onedrive/blob/master/docs/Docker.md
```sh
mkdir ~/OneDrive
mkdir ~/.config/onedrive

vim ~/.config/onedrive/config
# 添加排除同步的目錄和文件
skip_dir = "dir1|dir2|dir3"
skip_dir = "root/path/to/dir1|root/path/to/dir2"
skip_dir = "Data/Backup"
skip_file = "Data/file.txt"
```
※ 第一次運行需要輸入API Token
```sh
docker run -it --name onedrive \
    -v ~/.config/onedrive:/onedrive/conf \
    -v ~/OneDrive:/onedrive/data \
    -e ONEDRIVE_UID=1000 \
    -e ONEDRIVE_GID=1000 \
    -e ONEDRIVE_RESYNC=1 \
    --restart unless-stopped
    driveone/onedrive:latest
```


## Jellyfin
* https://jellyfin.org/docs/general/administration/installing.html#docker
```sh
sudo mkdir -p /docker/jellyfin/{config,cache}
sudo chown kaysiness:kaysiness -R /docker/jellyfin
```
新建`docker-compose.yml`文件
```yml
version: "3.6"
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    user: 1000:1000
    restart: "unless-stopped"
    environment:
      - 'ServerIP=10.0.0.50'
      - 'TZ=Asia/Shanghai'
    expose:
      - 8096
    networks:
      home:
        ipv4_address: 10.0.0.50
    volumes:
      - '/docker/jellyfin/data/config:/config'
      - '/docker/jellyfin/data/cache:/cache'
      - '/usr/share/fonts/noto-cjk:/usr/share/fonts:ro'
      - '/home/kaysiness/.local/share/fonts:/config/fonts:ro'
      - '/dev/shm/jellyfinTranscodecs:/config/transcodes'
    devices:
      # VAAPI Devices
      - '/dev/dri/renderD128:/dev/dri/renderD128'
      - '/dev/dri/card0:/dev/dri/card0'
    group_add:
      # VAAPI 还需要把render组添加到docker权限，该组ID可以在/etc/group查看
      - '989'
    labels:
      # containrrr/watchtower自动更新
      - com.centurylinklabs.watchtower.enable=true

networks:
  home:
    external: true
    name: home
```
運行容器
```sh
sudo docker-compose up
```

# [Flatpak](https://wiki.archlinux.org/title/Flatpak)
※ 一般情況下，本章節所有的`flatpak`命令都是以普通權限用戶運行，相當於`flatpak --user <command>`。
```sh
yay -S flatpak
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

對Flatpak進行一些設定
```sh
# 設定默認語言
flatpak config --set languages 'en;zh'
flatpak config --set extra-languages 'zh_CN.UTF-8;zh_TW.UTF-8'

# 修改源
# ref: https://mirror.sjtu.edu.cn/docs/flathub
sudo flatpak remote-modify flathub --url=https://mirror.sjtu.edu.cn/flathub

# 添加Beta源

```

常用指令
```sh
# 删除软件并清除数据
flatpak uninstall --delete-data <app>

# 查看软件的权限
flatpak info --show-permissions <app>

# 覆盖默认权限
flatpak override --filesystem=/mnt[:ro] <app>
flatpak override --nofilesystem=/mnt <app>

# 重设为默认的权限
flatpak override --reset <app>
```

## 解決字體問題
```sh
flatpak override <app> --filesystem=~/.local/share/fonts:ro --filesystem=~/.config/fontconfig:ro
ln -sf ~/.config/fontconfig ~/.var/app/<app>/config

#如果安裝的App多的話，也可以使用以下指令批量完成
sudo flatpak override --system --filesystem=~/.local/share/fonts:ro --filesystem=~/.config/fontconfig:ro
for app in ~/.var/app/*; do
  ln -s ~/.config/fontconfig ~/.var/app/$app/config
done
```


## 其他各種會用到的軟件
* LibreOffice：`flatpak install flathub org.libreoffice.LibreOffice`
* ~~qView：`flatpak install flathub com.interversehq.qView`~~
* Visual Studio Code：`flatpak install flathub com.visualstudio.code`

### XnViewMP
```sh
flatpak install flathub com.xnview.XnViewMP

# 如果照片、视频都是存放在 /mnt,/media 这些目录，不能使用只读挂载--filesystem=/mnt:ro，否则XnView的OpenWith功能无法使用
flatpak override com.xnview.XnViewMP --filesystem=/mnt
```

### [Jellyfin Media Player](https://flathub.org/apps/details/com.github.iwalton3.jellyfin-media-player)
```sh
flatpak install flathub com.github.iwalton3.jellyfin-media-player

# 設置單獨的環境變量，讓程序使用指定的DPI值顯示。
flatpak override --env=QT_AUTO_SCREEN_SCALE_FACTOR=1 com.github.iwalton3.jellyfin-media-player
```
  

# 常用軟件
* ~~Visual Studio Code：`yay -S vscodium libdbusmenu-glib`~~
* ~~XnView MP：`yay -S xnviewmp-system-libs`~~
* qView：`yay -S qview`


# 遊戲相關
## Steam
```sh
flatpak install flathub com.valvesoftware.Steam

# 讓Steam能訪問到其他位置上的遊戲庫
flatpak override com.valvesoftware.Steam --filesystem=/path/to/directory

# HiDPI縮放
flatpak override com.valvesoftware.Steam --env=QT_AUTO_SCREEN_SCALE_FACTOR=1 --env=GDK_SCALE=2

# 代理(但應該是不起作用的)
flatpak override com.valvesoftware.Steam --env=HTTP_PROXY=http://127.0.0.1:8080 --env=HTTPS_PROXY=http://127.0.0.1:8080
```


## 顯卡直通給Windows Guest虛擬機
* https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF
* https://doowzs.com/posts/2021/04/rtx-vfio-passthrough/

### 前期準備
* 主板BIOS開啟iommu和CPU虛擬化
* 我的硬體為
  * CPU: AMD Ryzen 7 5700G with Radeon Graphics
  * GPU: GeForce GTX 960
  * MEM: 32GB

※ 此處是把GTX 960直通給虛擬機

#### [找出並記下IOMMU分組](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Ensuring_that_the_groups_are_valid)
```sh
#!/bin/bash
shopt -s nullglob
for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V); do
    echo "IOMMU Group ${g##*/}:"
    for d in $g/devices/*; do
        echo -e "\t$(lspci -nns ${d##*/})"
    done;
done;
```
執行上面的腳本，找到顯卡所對應的設備ID
```
IOMMU Group 10:
        01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GM206 [GeForce GTX 960] [10de:1401] (rev a1)
        01:00.1 Audio device [0403]: NVIDIA Corporation GM206 High Definition Audio Controller [10de:0fba] (rev a1)
```
這裡是`10de:1401`和`10de:0fba`

### 隔離GPU
編輯`/etc/default/grub`，修改`GRUB_CMDLINE_LINUX_DEFAULT`的值，添加上設備ID
```sh
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet iommu=pt vfio-pci.ids=10de:1401,10de:0fba"
```

重新生成`grub.cfg`
```sh
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

提前加载`vfio-pci`內核模塊。編輯`/etc/mkinitcpio.conf`
```sh
MODULES=(vfio_pci vfio vfio_iommu_type1 vfio_virqfd)
```

重新生成mkinitcpio
```sh
sudo mkinitcpio -P
```

以上都完成後，重啟電腦

執行`lspci -nnv`，如果內核驅動顯示為`vfio-pci`則成功了
```sh
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GM206 [GeForce GTX 960] [10de:1401] (rev a1) (prog-if 00 [VGA controller])
        Subsystem: ASUSTeK Computer Inc. Device [1043:8520]
        Flags: bus master, fast devsel, latency 0, IRQ 82, IOMMU group 10
        Memory at f5000000 (32-bit, non-prefetchable) [size=16M]
        Memory at c0000000 (64-bit, prefetchable) [size=256M]
        Memory at d0000000 (64-bit, prefetchable) [size=32M]
        I/O ports at f000 [size=128]
        Expansion ROM at f6000000 [disabled] [size=512K]
        Capabilities: <access denied>
        Kernel driver in use: vfio-pci
        Kernel modules: nouveau
```

### 安裝必要軟體
```sh
yay -S libvirt virt-manager \
       iptables-nft dnsmasq dmidecode \ # NAT網絡所需組件
       qemu-base \
       edk2-ovmf \
       samba # 如果需要共享檔案給虛擬機，需要用到SMB

# 把當前用戶添加到libvirt組，可讓每次打開virt-manager時不需要密碼
sudo gpasswd -a kaysiness libvirt

# 啟用相應Deamon
sudo systemctl enable --now libvirtd.service
```

注意事項：  
* 默認的NAT網絡`default`預設是不啟用的，以下命令可以設定為開機啟用和立即啟用網絡
  * `sudo virsh net-autostart default`
  * `sudo virsh net-start default`

### 安裝Windows 10

注意事項：
* 芯片組選`Q35`，固件選`UEFI x86_64: /usr/share/edk2-ovmf/x64/OVMF_CODE.secboot.fd`
* CPU類型選`host-passthrough`
* 其他保持默認，先把系統安裝好後在添加直通顯卡進去

安裝完成後關閉虛擬機

### 修改Windows 10的虛擬設定
因為NVIDIA的驅動會檢查是否是虛擬機環境，所有要進行隱藏  
※ 以下這個XML內容都可以在`virt-manager`裡編輯
```xml
<features>
  <hyperv mode="custom">
    <vendor_id state="on" value="4cc49aed5d33"/>
    ......
  </hyperv>
  <kvm>
    <hidden state="on"/>
  </kvm>
  ......
</features>
```

在`virt-manager`裡把舊的虛擬硬解刪除，並把GTX 960和鼠標鍵盤加上去。

我是喜歡Host OS和Guest OS共用一套鼠標鍵盤，好處是不用額外把一組USB控制器分給虛擬機，只需要同時按住左右兩個Ctrl鍵即可在兩套OS之間切換。

首先查看鼠標鍵盤的設備路徑，執行`ls -l /dev/input/by-id/`，我的輸出結果如下
```
drwxr-xr-x  - root 07-06 11:05 /dev/input/by-id
lrwxrwxrwx 10 root 07-06 11:05 ├── usb-Microsoft_Microsoft®_2.4GHz_Transceiver_v8.0-event-if01 -> ../event10
lrwxrwxrwx 10 root 07-06 11:05 ├── usb-Microsoft_Microsoft®_2.4GHz_Transceiver_v8.0-event-if02 -> ../event12
lrwxrwxrwx  9 root 07-06 11:05 ├── usb-Microsoft_Microsoft®_2.4GHz_Transceiver_v8.0-event-kbd -> ../event8
lrwxrwxrwx  9 root 07-06 11:05 ├── usb-Microsoft_Microsoft®_2.4GHz_Transceiver_v8.0-if01-event-mouse -> ../event9
lrwxrwxrwx  9 root 07-06 11:05 ├── usb-Microsoft_Microsoft®_2.4GHz_Transceiver_v8.0-if01-mouse -> ../mouse0
lrwxrwxrwx 10 root 07-06 11:05 ├── usb-Microsoft_Microsoft®_2.4GHz_Transceiver_v8.0-if02-event-kbd -> ../event11
lrwxrwxrwx  9 root 07-06 11:05 ├── usb-USB_Keyboard_USB_Keyboard_C104A000000A-event-if01 -> ../event7
lrwxrwxrwx  9 root 07-06 11:05 └── usb-USB_Keyboard_USB_Keyboard_C104A000000A-event-kbd -> ../event6
```
正確的路徑是帶有event值這些，我這裡是`event9`和`event6`

然後增加以下的內容。PS2管線的那一套虛擬鼠標鍵盤是不能刪除的，保留即可
```xml
<devices>
  ......
  <input type="evdev">
    <source dev="/dev/input/by-id/usb-Microsoft_Microsoft&#xAE;_2.4GHz_Transceiver_v8.0-if01-event-mouse"/>
  </input>
  <input type="evdev">
    <source dev="/dev/input/by-id/usb-USB_Keyboard_USB_Keyboard_C104A000000A-event-kbd" grab="all" repeat="on"/>
  </input>
  <input type="mouse" bus="ps2"/>
  <input type="keyboard" bus="ps2"/>
  ......
</devices> 
```

編輯`default`網絡，給虛擬機分配一個固定IP地址
```xml
<network connections="1">
  <name>default</name>
  <uuid>2928a687-370c-4f94-99c3-459c749fe47c</uuid>
  <forward mode="nat">
    <nat>
      <port start="1024" end="65535"/>
    </nat>
  </forward>
  <bridge name="virbr0" stp="on" delay="0"/>
  <mac address="52:54:00:16:7c:1b"/>
  <ip address="192.168.122.1" netmask="255.255.255.0">
    <dhcp>
      <range start="192.168.122.2" end="192.168.122.254"/>
      <host mac="52:54:00:59:8d:9a" name="win10" ip="192.168.122.10"/>
    </dhcp>
  </ip>
</network>
```

給虛擬機添加各種協議的端口映射
```sh
sudo mkdir /etc/libvirt/hooks

sudo vim /etc/libvirt/hooks/qemu
#!/bin/bash
if [ "${1}" = "win10" ]; then # 修改为虚拟机的名称
   GUEST_IP=192.168.122.10 # 填入Windows虚拟机的IP地址
   for PORT in 3389 47984 47989 48010 47998 47999 48000; do
     if [ "${2}" = "stopped" ] || [ "${2}" = "reconnect" ]; then
        /sbin/iptables -D FORWARD -o virbr0 -p tcp -d $GUEST_IP --dport $PORT -j ACCEPT
        /sbin/iptables -t nat -D PREROUTING -p tcp --dport $PORT -j DNAT --to $GUEST_IP:$PORT
        /sbin/iptables -D FORWARD -o virbr0 -p udp -d $GUEST_IP --dport $PORT -j ACCEPT
        /sbin/iptables -t nat -D PREROUTING -p udp --dport $PORT -j DNAT --to $GUEST_IP:$PORT
     fi
     if [ "${2}" = "start" ] || [ "${2}" = "reconnect" ]; then
        /sbin/iptables -I FORWARD -o virbr0 -p tcp -d $GUEST_IP --dport $PORT -j ACCEPT
        /sbin/iptables -t nat -I PREROUTING -p tcp --dport $PORT -j DNAT --to $GUEST_IP:$PORT
        /sbin/iptables -I FORWARD -o virbr0 -p udp -d $GUEST_IP --dport $PORT -j ACCEPT
        /sbin/iptables -t nat -I PREROUTING -p udp --dport $PORT -j DNAT --to $GUEST_IP:$PORT
     fi
   done
fi

sudo chmod +x /etc/libvirt/hooks/qemu
```