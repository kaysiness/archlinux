- [備份舊系統](#備份舊系統)
  - [獲取已安裝的包名字](#獲取已安裝的包名字)
  - [備份目錄](#備份目錄)
- [安裝基本系統](#安裝基本系統)
  - [硬盤分區](#硬盤分區)
    - [創建btrfs子卷](#創建btrfs子卷)
    - [掛載分區](#掛載分區)
  - [安裝系統](#安裝系統)
  - [修改配置文件](#修改配置文件)
    - [/etc/mkinitcpio.conf](#etcmkinitcpioconf)
  - [安裝GRUB](#安裝grub)
  - [重啓前的準備](#重啓前的準備)
    - [新建普通用戶](#新建普通用戶)
    - [sudo](#sudo)
    - [啓用NTP](#啓用ntp)
    - [添加archlinuxcn源](#添加archlinuxcn源)
    - [安装NetworkManager](#安装networkmanager)
    - [提前修改系統環境變量](#提前修改系統環境變量)
  - [還原舊系統的備份](#還原舊系統的備份)
- [配置網絡](#配置網絡)
- [Btrfs快照](#btrfs快照)
  - [安裝grub-btrfs](#安裝grub-btrfs)
- [安裝桌面環境](#安裝桌面環境)
  - [安裝Wayland和顯卡驅動](#安裝wayland和顯卡驅動)
  - [PipeWire](#pipewire)
  - [字體](#字體)
  - [安裝KDE](#安裝kde)
    - [安装额外的软件](#安装额外的软件)
  - [輸入法Fcitx](#輸入法fcitx)
- [配置桌面環境](#配置桌面環境)
  - [創建家目錄下的默認目錄](#創建家目錄下的默認目錄)
  - [Firefox相關](#firefox相關)
    - [使用systemd啓動Firefox](#使用systemd啓動firefox)
- [Flatpak](#flatpak)
  - [解決字體問題](#解決字體問題)
  - [其他各種會用到的軟件](#其他各種會用到的軟件)
    - [XnViewMP](#xnviewmp)
    - [Jellyfin Media Player](#jellyfin-media-player)
- [常用軟件](#常用軟件)

---

記錄自己安裝Archlinux的過程。

# 備份舊系統
## 獲取已安裝的包名字
```sh
mkdir /mnt/backup
pacman -Qe > /mnt/backup/packagelist.txt
```
## 備份目錄
```sh
mkdir /mnt/backup/file
#將整個/home目錄複製到file下，包含home目錄自身
#如果是/home/的形式，則只複製home目錄下的內容，不包含home自身
sudo rsync -avrh --progress /home /mnt/backup/file/
sudo rsync -avrh --progress /docker /mnt/backup/file/
```


# 安裝基本系統
參照官方[Wiki](https://wiki.archlinux.org/title/Installation_guide)。

## 硬盤分區
因爲使用的是EUFI+GPT分區，在使用`fdisk`分區時需要將一個至少500MB大小的分區設成`EFI System`類型。以下稱爲esp分區。
```sh
# 格式化esp分區
mkfs.fat -F 32 -n BOOT /dev/nvme0n1p1

# 根分區。-n 32k指定node size，默認是16K。
mkfs.btrfs -L ROOT -n 32k /dev/nvme0n1p2
```

### 創建btrfs子卷
因為要用`Timeshift`來管理快照，所以只能用Ubuntu類型的子卷佈局。
```sh
# 掛載分區
mount /dev/nvme0n1p2 /mnt
# 創建子卷
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@pkg
# 卸載分區
umount /dev/nvme0n1p2
```

### 掛載分區
```sh
# 掛載根目錄
mount /dev/nvme0n1p2 /mnt -o subvol=@,rw,relatime,compress=zstd:3,discard=async,ssd,space_cache=v2,subvolid=5
# 掛載 /home 目錄
mkdir /mnt/home
mount /dev/nvme0n1p2 /mnt/home -o subvol=@home,relatime,compress=zstd:3,discard=async,ssd,space_cache=v2,subvolid=5
# 掛載 /var/log 目錄
mkdir -p /mnt/var/log
mount /dev/nvme0n1p2 /mnt/var/log -o subvol=@log,relatime,compress=zstd:3,discard=async,ssd,space_cache=v2,subvolid=5
# 掛載 /var/cache/pacman/pkg 目錄
mkdir -p /mnt/var/cache/pacman/pkg
mount /dev/nvme0n1p2 /mnt/var/cache/pacman/pkg -o subvol=@pkg,relatime,compress=zstd:3,discard=async,ssd,space_cache=v2,subvolid=5

# 禁用以下目錄的CoW
chattr +C /mnt/var/log
chattr +C /mnt/var/cache/pacman/pkg

# 掛載esp分區，我喜歡掛載爲/boot
mkdir /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot
```

## 安裝系統
```sh
pacstrap /mnt base linux-zen linux-zen-headers linux-firmware btrfs-progs grub efibootmgr sudo neovim bash-completion amd-ucode
```

## 修改配置文件
※ 以下這步是給之後的虛擬機顯卡直通做準備
### /etc/mkinitcpio.conf
```
MODULES=(vfio_pci vfio vfio_iommu_type1 kvm_amd)
```

最後別忘記執行`mkinitcpio -P`


## 安裝GRUB
```sh
nvim /etc/default/grub
# 等待時間，設置爲-1即一直等待
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

### sudo
```sh
env EDITOR=/usr/bin/nvim visudo /etc/sudoers.d/kaysiness
```
```
%wheel        ALL=(ALL:ALL) ALL
kaysiness     ALL=NOPASSWD: /usr/bin/pacman,/usr/bin/yay
```

### 啓用NTP
```sh
timedatectl set-ntp true
```

### 添加archlinuxcn源
※ 如需換源可以考慮使用 https://github.com/RubyMetric/chsrc

```sh
curl -L https://github.com/RubyMetric/chsrc/releases/download/pre/chsrc-x64-linux -o /tmp/chsrc; chmod +x /tmp/chsrc
/tmp/chsrc set archlinux
/tmp/chsrc set archlinuxcn
pacman -Syy archlinuxcn-keyring yay   # archlinuxcn-keyring 和 yay 不能同時安裝
```

※ `yay`位於`archlinuxcn`源，不启用的話就只能通過[AUR](https://aur.archlinux.org/packages/yay)安裝了。

### 安装NetworkManager
```sh
yay -S networkmanager
sudo systemctl enable NetworkManager.service
```

### 提前修改系統環境變量
```ini
# vi /etc/environment

# EDITOR
EDITOR=/usr/bin/nvim

# Proxy
HTTP_PROXY=
HTTPS_PROXY=
NO_PROXY=localhost,127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1,fc00::,*.lan
```

然後就能重啓進入Archlinux了。


## 還原舊系統的備份
第一次進入系統前，先使用`root`帳號登入，等還原備份後再切換到自己的帳號
```sh
rsync -avrh --progress /mnt/backup/file/home/ /home/
```

# 配置網絡
```sh
# 新建一个HOME连接并使用物理网卡enp1s0
nmcli connection add con-name HOME ifname enp1s0 type ethernet

# HOME连接使用DHCP配置IPv4
nmcli connection modify HOME ipv4.method auto

# 或者手动指定HOME连接的IPv4地址
nmcli connection modify HOME ipv4.addresses 10.0.0.10/16 ipv4.gateway 10.0.0.1 ipv4.dns 10.0.0.1

# 重新加载配置
nmcli connection reload
```

# Btrfs快照
```sh
# timeshift-autosnap包是用於每次系統更新前自動創建快照
yay -S timeshift timeshift-autosnap

# Timeshift需要用到corn服務
sudo systemctl enable --now cronie.service
```

## 安裝grub-btrfs
`grub-btrfs`包是生成GRUB配置自動添加快照入口，方便直接啟動系統到快照，不需要事先恢復快照。`inotify-tools`包是`grub-btrfs`的可選依賴，但為了自動生成GRUB配置需要安裝。
```sh
yay -S grub-btrfs inotify-tools

# 啟動服務自動生成GRUB配置
sudo systemctl enable --now grub-btrfsd.service
```

这个服务默认监视的快照路径在`/.snapshots`，而`Timeshift`创建的快照是一个动态变化的路径，想要让它监视`Timeshift`的快照路径需要编辑 service 文件。
```sh
sudo systemctl edit grub-btrfsd.service
```
```systemd
[Service]
ExecStart=/usr/bin/grub-btrfsd --syslog --timeshift-auto
```
这样`grub-btrfs`就会监视`Timeshift`创建的快照了。


默認下`Timeshift`创建的快照默认是可读写的，但若用其他的快照管理程序，创建的快照可能是只读的，这种情况下，直接启动进入快照可能会发生错误，这种情况`grub-btrfs`也提供了解决方案，编辑`/etc/mkinitcpio.conf`，在`HOOKS`後面加入`grub-btrfs-overlayfs`。
```
HOOKS=(base udev autodetect modconf block filesystems keyboard fsck grub-btrfs-overlayfs)
```

# 安裝桌面環境

此處用的是`AMD Ryzen5 5700G`自帶的核顯

## 安裝Wayland和顯卡驅動
參考
* https://wiki.archlinux.org/title/Xorg
* https://wiki.archlinux.org/title/AMDGPU

```sh
yay -S wayland libinput mesa-vdpau vulkan-radeon
#yay -S xorg-server xf86-video-amdgpu mesa-vdpau vulkan-radeon # X11
```

## PipeWire
```sh
yay -S pipewire pipewire-alsa pipewire-pulse

# 一般安装完会自动启用不需要这两步
sudo systemctl enable pipewire-pulse.socket
systemctl --user enable pipewire-pulse.service
```

## 字體
```sh
yay -S ttf-dejavu \
       noto-fonts-cjk noto-fonts-emoji noto-fonts \
       wqy-microhei wey-zenhei \
       ttf-sarasa-gothic \
       ttf-lxgw-wenkai ttf-lxgw-wenkai-mono
```

## 安裝KDE
參考
* https://wiki.archlinux.org/title/KDE

注意事項
* `phonon`後端使用`GStreamer`
* `plasma-pa`和`plasma-nm`用於PulseAudio和NetworkManager的組件
* `powerdevil`電源管理，依賴與NetworkManager，如果不用的話可以裝AUR的[`powerdevil-light`](https://aur.archlinux.org/packages/powerdevil-light)
* 不嫌棄安裝一大堆沒用的包，可以直接安裝`yay -S plasma-meta kde-applications-meta`這兩個包，這樣整個KDE Plasms都裝上了。我是直接裝了這兩個meta包的，**下面命令安裝的包只是用於記錄**。

```sh
yay -S plasma-desktop plasma-pa plasma-nm \
       qt5-wayland qt6-wayland plasma-wayland-session \
       kscreen konsole kate \
       sddm sddm-kcm \
       kde-gtk-config breeze-gtk \
       powerdevil
               
sudo systemctl enable sddm.service
```

### 安装额外的软件
```sh
yay -S eza duf p7zip

# yay -S kde-applications
yay -S dolphin dolphin-plugins kclac krdc yakuake kclock kdeconnect kdenetwork-filesharing
yay -S gwenview krita ffmpegthumbs okular ark
```

## 輸入法Fcitx
* https://wiki.archlinux.org/title/Fcitx5
* [Rime設定](https://github.com/wongdean/rime-settings)

```sh
yay -S fcitx5-im fcitx5-rime fcitx5-mozc rime-ice-git
```

※ System Settings > Regional Settings > Input Method > Configure addons > 「經典用戶界面」旁邊的設置圖標 > 修改「字體」/「垂直候選列表」等，可以改變打字時選字的界面。

# 配置桌面環境
※ **從舊系統恢復的話可以跳過此步驟**

## 創建家目錄下的默認目錄
```sh
yay -S xdg-user-dirs
LC_ALL=C xdg-user-dirs-update --force   # 使用英文名字創建
```

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


# [Flatpak](https://wiki.archlinux.org/title/Flatpak)
※ 一般情況下，本章節所有的`flatpak`命令都是以普通權限用戶運行，相當於`flatpak --user <command>`。
```sh
yay -S flatpak flatpak-kcm
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
| 名字                  | 命令                                                    |
| --------------------- | ------------------------------------------------------- |
| ~~LibreOffice~~       | `flatpak install flathub org.libreoffice.LibreOffice`   |
| ONLYOFFICE            | `flatpak install flathub org.onlyoffice.desktopeditors` |
| Visual Studio Code    | `flatpak install flathub com.visualstudio.code`         |
| Flatseal              | `flatpak install falthub com.github.tchx84.Flatseal`    |
| Google Chrome         | `flatpak install flathub com.google.Chrome`             |
| Microsoft Edge        | `flatpak install flathub com.microsoft.Edge`            |
| Lutris                | `flatpak install flathub net.lutris.Lutris`             |
| ProtonUp-Qt           | `flatpak install flathub net.davidotek.pupgui2`         |
| Heroic Games Launcher | `flatpak install flathub com.heroicgameslauncher.hgl`   |
| Chiaki                | `flatpak install flathub re.chiaki.Chiaki`              |

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
| 名字                   | 命令                               |
| ---------------------- | ---------------------------------- |
| ~~Visual Studio Code~~ | `yay -S vscodium libdbusmenu-glib` |
| XnView MP              | `yay -S xnviewmp-system-libs`      |
| qView                  | `yay -S qview`                     |
