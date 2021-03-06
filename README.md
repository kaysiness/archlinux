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
  - [PulseAudio](#pulseaudio)
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
  - [OneDrive](#onedrive)
  - [Jellyfin](#jellyfin)
- [Flatpak](#flatpak)
  - [Jellyfin Media Player](#jellyfin-media-player)
  - [其他各種會用到的軟件](#其他各種會用到的軟件)
- [常用軟件](#常用軟件)
- [遊戲相關](#遊戲相關)
  - [Steam](#steam)
  - [顯卡直通給Windows Guest虛擬機](#顯卡直通給windows-guest虛擬機)
    - [前期準備](#前期準備)

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

## PulseAudio
```sh
yay -S pulseaudio pulseaudio-alsa
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
TODO


# Docker
```sh
yay -S docker docker-compose
sudo systemctl enable docker.service
```
※ 我個人比較喜歡把Docker的各種容器配置文件放在`/docker`下。
```sh
sudo mkdir /docker
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
version: "3.5"
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    user: 1000:1000
    network_mode: "host"
    volumes:
      - /docker/jellyfin/config:/config
      - /docker/jellyfin/cache:/cache
      - /mnt/bangumi:/bangumi:ro
    restart: "unless-stopped"
    # 我的ISP屏蔽了The Movies Database，所以需要設置代理
    environment:
      - HTTP_PROXY=http://127.0.0.1:8080
      - HTTPS_PROXY=http://127.0.0.1:8080
```
運行容器
```sh
sudo docker-compose up
```

# [Flatpak](https://wiki.archlinux.org/title/Flatpak)

```sh
yay -S flatpak
```

對Flatpak進行一些設定
```sh
# 設定默認語言
flatpak config --user --set languages 'en;zh'
flatpak config --user --set extra-languages 'zh_CN.UTF-8;zh_TW.UTF-8'
```

## [Jellyfin Media Player](https://flathub.org/apps/details/com.github.iwalton3.jellyfin-media-player)
```sh
flatpak install flathub com.github.iwalton3.jellyfin-media-player
```

※ 設置單獨的環境變量，讓程序使用指定的DPI值顯示。
```sh
flatpak override --user --env=QT_AUTO_SCREEN_SCALE_FACTOR=1 com.github.iwalton3.jellyfin-media-player
```

## 其他各種會用到的軟件
* LibreOffice：`flatpak install flathub org.libreoffice.LibreOffice`
* ~~qView：`flatpak install flathub com.interversehq.qView`~~
* Visual Studio Code：`flatpak install flathub com.visualstudio.code`

# 常用軟件
* ~~Visual Studio Code：`yay -S vscodium libdbusmenu-glib`~~
* XnView MP：`yay -S xnviewmp-system-libs`
* qView：`yay -S qview`

# 遊戲相關
## Steam
```sh
flatpak install flathub com.valvesoftware.Steam

# 讓Steam能訪問到其他位置上的遊戲庫
flatpak override com.valvesoftware.Steam --filesystem=/path/to/directory

# 解決字體問題
flatpak override com.valvesoftware.Steam --filesystem=~/.local/share/fonts --filesystem=~/.config/fontconfig
```


## 顯卡直通給Windows Guest虛擬機
* https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF

### 前期準備
* 主板BIOS開啟iommu和虛擬化
* 