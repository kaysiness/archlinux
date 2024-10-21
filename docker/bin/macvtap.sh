#!/usr/bin/env bash

declare -r PATH=/usr/sbin:/usr/bin:/sbin:/bin

while getopts 'm:' OPTS; do
  case "$OPTS" in
    m)
      model="$OPTARG"
      ;;
    *)
      echo usage: $0 -m "<add|del>"
      exit 0
      ;;
  esac
done
shift "$(($OPTIND - 1))"

# 檢查參數是否正確
if [ -z "$model" ]; then
  echo "usage: $0 -m <add|del>"
  exit 1
fi

netMactap="tap1s0"
netDevice="enp1s0"

# 創建/刪除macvtap網卡
case "$model" in
  add)
    ip link add link ${netDevice} name ${netMactap} type macvtap mode bridge
    ip link set ${netMactap} up
    ip route add 10.0.101.0/24 dev ${netMactap} metric 90
    ;;
  del)
    ip route del 10.0.101.0/24 dev ${netMactap}
    ip link set ${netMactap} down
    ip link delete ${netMactap}
    ;;
  *)
    echo usage: $0 -m "<add|del>"
    exit 1
    ;;
esac