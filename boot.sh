#!/bin/bash
exec>/var/log/boot.log 2>&1
m=/mnt/pvc
mkdir -p $m
blkid /dev/vdb||mkfs.ext4 /dev/vdb
mountpoint -q $m||mount /dev/vdb $m
grep -q /dev/vdb /etc/fstab||echo "/dev/vdb $m ext4 defaults 0 2">>/etc/fstab
mkdir -p $m/dk $m/ac $m/bin $m/lib $m/svc

[ -L /var/lib/docker ]||(rm -rf /var/lib/docker&&ln -s $m/dk /var/lib/docker)
[ -L /var/cache/apt ]||(rm -rf /var/cache/apt&&ln -s $m/ac /var/cache/apt)

ip link set dev enp1s0 mtu 1350

if [ ! -f $m/bin/docker ];then
  apt-get clean
  rm -rf /var/lib/apt/lists
  mkdir -p /var/lib/apt/lists/partial
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io nordvpn
  cp -a /usr/bin/docker /usr/bin/dockerd /usr/bin/docker-init /usr/bin/docker-proxy $m/bin/ 2>/dev/null||true
  cp -a /usr/sbin/containerd* /usr/sbin/runc $m/bin/ 2>/dev/null||true
  cp -a /usr/sbin/nordvpnd /usr/bin/nordvpn $m/bin/ 2>/dev/null||true
  cp -a /lib/systemd/system/docker.service /lib/systemd/system/docker.socket \
        /lib/systemd/system/containerd.service /lib/systemd/system/nordvpnd.service \
        $m/svc/ 2>/dev/null||true
  cp -rp /usr/lib/nordvpn $m/lib/ 2>/dev/null||true
else
  cp -a $m/bin/docker* $m/bin/containerd* $m/bin/runc /usr/bin/ 2>/dev/null||true
  cp -a $m/bin/nordvpnd /usr/bin/nordvpn /usr/bin/ 2>/dev/null||true
  cp -a $m/svc/* /lib/systemd/system/ 2>/dev/null||true
  [ -d $m/lib/nordvpn ]&&cp -rp $m/lib/nordvpn /usr/lib/||true
fi

mkdir -p /etc/docker
printf '{"data-root":"/var/lib/docker","exec-opts":["native.cgroupdriver=cgroupfs"],"storage-driver":"overlay2"}' > /etc/docker/daemon.json
systemctl daemon-reload
systemctl enable --now nordvpnd containerd docker
nordvpn set technology openvpn&&nordvpn set protocol tcp
nordvpn set ipv6 off&&nordvpn whitelist add port 22
