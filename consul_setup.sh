#!/bin/bash
CONSUL=1.0.0
apt update
apt install -y unzip wget jq awscli
curl -o consul_$${CONSUL}_linux_amd64.zip https://releases.hashicorp.com/consul/$${CONSUL}/consul_$${CONSUL}_linux_amd64.zip
unzip -o consul_$${CONSUL}_linux_amd64.zip
mv consul /usr/bin/consul

#mkdir /root/go
#export GOPATH=/root/go
#go get github.com/pshima/consul-snapshot
#mv /root/go/bin/consul-snapshot /usr/bin/consul-snapshot



#Install the SystemD Unit file
cat << 'EOF' > /etc/systemd/system/consul.service
[Unit]
Description=consul agent
Requires=network-online.target
After=network-online.target

[Service]
EnvironmentFile=-/etc/sysconfig/consul
Restart=on-failure
ExecStart=/usr/bin/consul agent $OPTIONS -ui -config-dir=/etc/consul.d -client="0.0.0.0"
ExecStop=/usr/bin/consul leave
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF

#Install the SystemD Unit file for the snapshot backup service
#cat << 'EOF' > /etc/systemd/system/consul-snapshot.service
#[Unit]
#Description=consul-snapshot
#Requires=network-online.target
#After=network-online.target

#[Service]
#EnvironmentFile=-/etc/sysconfig/consul-snapshot
#Environment=S3BUCKET=${bucket}
#Environment=S3REGION=${region}
#Environment=BACKUPINTERVAL=1800
#Restart=on-failure
#ExecStart=/usr/bin/consul-snapshot backup
#ExecReload=/bin/kill -HUP $MAINPID
#KillSignal=SIGTERM

#[Install]
#WantedBy=multi-user.target
#EOF

systemctl enable consul.service
#systemctl enable consul-snapshot.service

#Install the consul config dirs
mkdir /etc/consul.d

cat << EOF > /etc/consul.d/000-consul.json
{
  "bootstrap_expect": ${num_servers},
  "encrypt": "${encryption_key}",
  "server": true,
  "datacenter": "${region}",
  "data_dir": "/var/lib/consul",
  "log_level": "INFO",
  "enable_syslog": true,
  "retry_join": [
    "provider=aws tag_key=consul-cluster tag_value=${region}"
  ],
  "autopilot": {
    "cleanup_dead_servers": true,
    "last_contact_threshold": "200ms",
    "max_trailing_logs": 250,
    "server_stabilization_time": "10s",
    "upgrade_version_tag": ""
  },
  "performance": {
    "raft_multiplier": 1
  }
}
EOF

instanceID=$(curl http://169.254.169.254/latest/meta-data/instance-id)
hostname="consul-$${instanceID}"
serverInt=1


hostnamectl set-hostname $hostname

# Clear any old state from the build process
rm -rf /var/lib/consul/*

systemctl start consul
#systemctl start consul-snapshot
