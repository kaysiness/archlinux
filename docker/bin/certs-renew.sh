#!/usr/bin/env bash

declare -r PATH=/usr/bin:/bin
declare -r certName="docker.kkun.date"   # 如有多個域名，通過空格分開寫入下面的變量
declare -r workDir=/docker/nginx-proxy/certs

for name in ${certName}; do
  crtName=${name}.crt
  keyName=${name}.key

  chmod 400 ${workDir}/${keyName}
  chmod 444 ${workDir}/${crtName}
done

docker restart nginx-proxy