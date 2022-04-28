# 前言
記錄下我在使用Archlinux時的各種折騰，已方便日後繼續折騰🙃

# 安裝基本系統
參照官方[Wiki](https://wiki.archlinux.org/title/Installation_guide)。

## 硬盤分區
因爲使用的是EUFI+GPT分區，在使用`fdisk`分區時需要將一個至少500MB大小的分區設成`EFI System`類型。
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
pacman -Sy os-prober
vim /etc/default/grub
```
```apache
# 允許GRUB發現其他分區上的系統
GRUB_DISABLE_OS_PROBER=true

# 等待時間
GRUB_TIMEOUT=0
```

```sh
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
```

## 重啓前的準備

新建普通用戶
```sh
useradd -m -G wheel -s /bin/bash kaysiness
passwd kaysiness
```
讓普通用戶使用sudo
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
然後就能重啓進入Archlinux了。

# 安裝桌面環境

此處用的是`AMD Ryzen5 3400G`自帶的核顯

## 安裝Xorg和顯卡驅動
參考
* https://wiki.archlinux.org/title/Xorg
* https://wiki.archlinux.org/title/AMDGPU
```sh
sudo pacman -S xorg-server xf86-video-amdgpu \
               mesa-vdpau \
               vulkan-radeon
```

## PulseAudio
```sh
sudo pacman -S pulseaudio pulseaudio-alsa
```

## NetworkManager
```sh
sudo pacman -S networkmanager
sudo systemctl enable NetworkManager.service
```

## 字體
```sh
sudo pacman -S ttf-dejavu \
               noto-fonts-cjk noto-fonts-emoji noto-fonts \
               wqy-microhei
```

## 安裝KDE
參考
* https://wiki.archlinux.org/title/KDE

注意事項
* `phonon`後端使用`GStreamer`
* `plasma-pa`和`plasma-nm`用於PulseAudio和NetworkManager的組件
* `powerdevil`電源管理。如果不用NetworkManager的話可以裝AUR裏的`powerdevil-light`
```sh
sudo pacman -S plasma-desktop kde-applications-meta \
               plasma-pa plasma-nm \
               sddm sddm-kcm \
               kde-gtk-config breeze-gtk
               
sudo systemctl enable sddm.service
```

## 輸入法Fcitx
* https://wiki.archlinux.org/title/Fcitx5_(%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87)
* [Rime設定](https://github.com/wongdean/rime-settings)
```sh
sudo pacman -S fcitx5-im fcitx5-rime fcitx5-mozc
```

# 配置KDE

## 創建家目錄下的默認目錄
```sh
sudo pacman -S xdg-user-dirs
LC_ALL=C xdg-user-dirs-update --force   # 使用英文名字創建
```

## 環境變量
TODO

## HiDPI
* https://wiki.archlinux.org/title/HiDPI#KDE_Plasma

把`Force fonts DPI`改成`144`。等效於Windows下的150%縮放。

設定環境變量`PLASMA_USE_QT_SCALING=1`，讓tray icons也遵循該縮放設定。

## Firefox相關
```sh
sudo pacman -S firefox firefox-i18n-zh-tw
firefox -P
```
讓Firefox和KDE集成
* https://wiki.archlinux.org/title/Firefox#KDE_integration


# Zsh
* https://wiki.archlinux.org/title/Zsh
```sh
sudo pacman -S zsh zsh-completions grml-zsh-config
```
TODO
