#!/usr/bin/env bash

set -e
set -u
set -x
set -o pipefail

if [[ $(grep "isMaster" /mnt/var/lib/info/instance.json | grep true) ]]; then
  echo "I am a Master"
  IS_MASTER=1
else
  echo "I am a Slave, exiting"
  exit 0
fi

USERS=$(< /opt/dataworks/users)

for USER in ${USERS[@]}; do
  sudo -H -u hdfs bash -c "hdfs dfs -mkdir /user/$USER"
  sudo -H -u hdfs bash -c "hdfs dfs -chown -R $USER:$USER /user/$USER"
  sudo -H -u hdfs bash -c "hdfs dfs -chmod 770 /user/$USER"
done

sudo cp /usr/share/java/mariadb-connector-java.jar /usr/lib/spark/jars/

##### Fix up Hive
echo -e "\nexport AWS_STS_REGIONAL_ENDPOINTS=regional" | sudo tee -a /etc/hive/conf/hive-env.sh
chmod 444 /var/aws/emr/userData.json

sudo stop hive-server2
sleep 5
sudo start hive-server2
