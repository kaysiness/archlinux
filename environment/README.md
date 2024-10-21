把`*.conf`文件放在`${HOMW}/.config/environment.d/`目录下

另外`KDE Plasma`还有一个`${HOME}/.config/plasma-workspace/env/`目录，可以把GUI相关的存放在这里，文件格式为`*.sh`

可以使用`systemctl --user show-environment`來檢查是否生效。

btw，臨時設置一個圖形環境可用的環境變量，可以用`systemctl --user set-environment <env>=<value>`