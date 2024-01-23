#!/bin/bash

# The device/thing should be created first in the cloud and below are some commands to create the device in the cloud#
# aws iot describe-endpoint --endpoint-type iot:CredentialProvider
# aws iot create-thing --thing-name DevIoTDevice1
# aws iot create-thing-group --thing-group-name DevIoTGroup
#aws iot create-keys-and-certificate --set-as-active --certificate-pem-outfile greengrass-v2-certs/device.pem.crt --public-key-outfile greengrass-v2-certs/public.pem.key --private-key-outfile greengrass-v2-certs/private.pem.key
#aws iot attach-thing-principal --thing-name DevIoTDevice1 --principal arn:aws:iot:eu-central-1:085148982124:cert/afaf0ddf0c7a78a888f91c0bc4422a43e4d2dfdaa370c1653ea4b9d9492ea16a
#aws iot create-policy --policy-name   DevGreengrassV2IoTThingPolicy  --policy-document file://greengrass-v2-iot-policy.json
# aws iam create-role --role-name DevGreengrassV2TokenExchangeRole --assume-role-policy-document file://device-role-trust-policy.json
# aws iam create-policy --policy-name DevGreengrassV2TokenExchangeRoleAccess --policy-document file://device-role-access-policy.json
# aws iam attach-role-policy --role-name DevGreengrassV2TokenExchangeRole --policy-arn  arn:aws:iam::085148982124:policy/DevGreengrassV2TokenExchangeRoleAccess
# aws iot create-role-alias --role-alias DevGreengrassCoreTokenExchangeRoleAlias --role-arn arn:aws:iam::085148982124:role/DevGreengrassV2TokenExchangeRole
# aws iot create-policy --policy-name DevGreengrassCoreTokenExchangeRoleAliasPolicy --policy-document file://greengrass-v2-iot-role-alias-policy.json

log () {
   echo $1 >/dev/tty1
   echo $1 >> /etc/install.log
}

configJava(){

# install Java
 tar xf /root/extras/OpenJDK21U-jdk_x64_linux_hotspot_21.0.1_12.tar.gz -C /opt 
 echo  "JAVA_HOME=\"/opt/jdk-21.0.1+12\"" | tee -a /etc/profile
 echo  "export JAVA_HOME"  | tee -a /etc/profile
 echo  "PATH=\"\$JAVA_HOME/bin:\$PATH\""  | tee -a /etc/profile
 echo  "export PATH"  | tee -a /etc/profile
}


installDocker(){
   log "Installing docker cli"
   cd /root/extras/
   rpm-ostree  install docker-ce-cli-24.0.7-1.fc39.x86_64.rpm
   log "Installing containerd"
   rpm-ostree  install containerd.io-1.6.24-3.1.fc39.x86_64.rpm
   log "Installing libcgroup"
   rpm-ostree  install libcgroup-3.0-3.fc39.x86_64.rpm
   log "Installing docker engine"
   rpm-ostree  install docker-ce-24.0.7-1.fc39.x86_64.rpm
   log "Installing docker compose plugin"
   rpm-ostree  install docker-compose-plugin-2.21.0-1.fc39.x86_64.rpm
   log "Installing docker buildx plugin"
   rpm-ostree  install docker-buildx-plugin-0.11.2-1.fc39.x86_64.rpm
 
}

createGgcUser(){
   groupadd ggc_group
   getent group docker >> /etc/group  
	useradd ggc_user -G ggc_group,docker,wheel
}

configFixedIP(){
   log "Configuring fixed IP"
   nmcli connection modify enp0s3 ipv4.method manual ipv4.address 10.10.175.50/24 ipv4.gateway 10.10.175.1 ipv4.dns 10.10.175.1

}

terminateStartupService(){
   log "Docker and group is added the service will be terminated now"
   systemctl stop startup
   systemctl disable startup
   systemctl daemon-reload
}

installUtilities(){
   log "Installing unzip"
   rpm-ostree  install unzip-6.0-62.fc39.x86_64.rpm
}

installGreenGrassCore(){  
   #Moving greengrass files to ggc_user home directory
   mv /root/extras/greengrass-nucleus-latest.zip /var/home/ggc_user/
   mv /root/extras/config.yaml /var/home/ggc_user/
   mv /root/extras/$CRT_FILE_NAME /var/home/ggc_user/
   mv /root/extras/$KEY_FILE_NAME /var/home/ggc_user/
   mv /root/extras/$ROOT_CA_FILE_NAME /var/home/ggc_user/

   chown ggc_user:ggc_group /var/home/ggc_user/*
   log "Chaning the primary group of the ggc_user"
   usermod -g ggc_group ggc_user
   

   #Installing greengrass core with ggc_user
   su - ggc_user -c "mkdir -p /var/home/ggc_user/GreengrassInstaller"
   su - ggc_user -c "mv /var/home/ggc_user/config.yaml /var/home/ggc_user/GreengrassInstaller/"

   su - ggc_user -c "unzip /var/home/ggc_user/greengrass-nucleus-latest.zip -d /var/home/ggc_user/GreengrassInstaller" && rm /var/home/ggc_user/greengrass-nucleus-latest.zip
   su - ggc_user -c "mkdir -p /var/home/ggc_user/greengrass/v2"
   #GREENGRASS_VERSION=$(java -jar /var/home/ggc_user/GreengrassInstaller/lib/Greengrass.jar --version | grep -oP 'v\K.*')
   #log $GREENGRASS_VERSION
   su - ggc_user -c "mv /var/home/ggc_user/$ROOT_CA_FILE_NAME /var/home/ggc_user/greengrass/v2/"
   su - ggc_user -c "mv /var/home/ggc_user/$CRT_FILE_NAME /var/home/ggc_user/greengrass/v2/"
   su - ggc_user -c "mv /var/home/ggc_user/$KEY_FILE_NAME /var/home/ggc_user/greengrass/v2/"
   # su - ggc_user -c "mv /var/home/ggc_user/config.yaml /var/home/ggc_user/GreengrassInstaller/"

   su - ggc_user -c "sed -i "s/__certificateFile__/"$CRT_FILE_NAME"/" /var/home/ggc_user/GreengrassInstaller/config.yaml"
   su - ggc_user -c "sed -i "s/__privateKey__/"$KEY_FILE_NAME"/" /var/home/ggc_user/GreengrassInstaller/config.yaml"
   su - ggc_user -c "sed -i "s/__rootCa__/"$ROOT_CA_FILE_NAME"/" /var/home/ggc_user/GreengrassInstaller/config.yaml"

   su - ggc_user -c "sed -i "s/__thingName__/"$THING_NAME"/" /var/home/ggc_user/GreengrassInstaller/config.yaml"
   su - ggc_user -c "sed -i "s/__version__/"$GREENGRASS_VERSION"/" /var/home/ggc_user/GreengrassInstaller/config.yaml"
   su - ggc_user -c "sed -i "s/__awsRegion__/"$REGION"/" /var/home/ggc_user/GreengrassInstaller/config.yaml"
   su - ggc_user -c "sed -i "s/__iotRoleAlias__/"$iotRoleAlias"/" /var/home/ggc_user/GreengrassInstaller/config.yaml"
   su - ggc_user -c "sed -i "s/__iotDataEndpoint__/"$IOT_DATA_ENDPOINT"/" /var/home/ggc_user/GreengrassInstaller/config.yaml"
   su - ggc_user -c "sed -i "s/__iotCredentialsEndpoint__/"$IOT_CREDENTIALS_ENDPOINT"/" /var/home/ggc_user/GreengrassInstaller/config.yaml"

   su - ggc_user -c "nohup java -Droot="/var/home/ggc_user/greengrass/v2" -Dlog.store=FILE \
  -jar /var/home/ggc_user/GreengrassInstaller/lib/Greengrass.jar \
  --init-config /var/home/ggc_user/GreengrassInstaller/config.yaml \
  --component-default-user ggc_user:ggc_group \
  --setup-system-service false &"


 sed -i '/\[Service\]/a\Environment=PATH=/opt/jdk-21.0.1+12/bin:'$PATH /root/extras/greengrass.service
 mv /root/extras/greengrass.service /etc/systemd/system/
 systemctl daemon-reload
 systemctl enable greengrass.service
 sleep 5
 pkill -f 'java -D'
 systemctl start greengrass.service

 log "starting the plugin component ... [ $DL_GW_COMPONENT ]"
 
 mkdir -p /var/home/ggc_user/environment/GreengrassCore/artifacts/$DL_GW_COMPONENT/$DL_GW_VERSION  /var/home/ggc_user/environment/GreengrassCore/recipes/

 mv /root/extras/$DL_GW_RECIPE /var/home/ggc_user/environment/GreengrassCore/recipes/
 mv /root/extras/$DL_GW_ARTIFACT /var/home/ggc_user/environment/GreengrassCore/artifacts/$DL_GW_COMPONENT/$DL_GW_VERSION/

 chown -R ggc_user:ggc_group /var/home/ggc_user/environment

 
}

installGreenGrassComponents(){
   
   log "Logging to Aggreko ACR"
   su - ggc_user -c "docker login aggrekoberlin.azurecr.io -u="236deb7a-424e-4f09-a379-2ef8ec89667c" -p="BuF8Q~P6preAQCjxH_QLltFdZMiiBWt7R0VnMb7-" "
   log "After logging to Aggreko ACR"
   log "waiting till greenGrass cli get installed ..."
   until [ -f /var/home/ggc_user/greengrass/v2/bin/greengrass-cli ]
   do    
     sleep 5
   done
   log "greenGrass-cli found !"
   echo "alias gg=/var/home/ggc_user/greengrass/v2/bin/greengrass-cli" >> /etc/profile
   source /etc/profile
   # A delay to ensure GG cli command is installed
   sleep 20
   /var/home/ggc_user/greengrass/v2/bin/greengrass-cli deployment create  --recipeDir /var/home/ggc_user/environment/GreengrassCore/recipes -a /var/home/ggc_user/environment/GreengrassCore/artifacts  -m $DL_GW_COMPONENT=$DL_GW_VERSION

}
#===================================== Main  ===================================== #

#******************* Variables ********************#
DOCKER_FILE="/etc/docker"
USER_FILE="/etc/user"
CRT_FILE_NAME="dev-device.pem.crt"
KEY_FILE_NAME="dev-private.pem.key"
ROOT_CA_FILE_NAME="AmazonRootCA1.pem"
IOT_DATA_ENDPOINT="ap4k1jxy0exn6-ats.iot.eu-central-1.amazonaws.com"
IOT_CREDENTIALS_ENDPOINT="c3ipvtonpgtzfp.credentials.iot.eu-central-1.amazonaws.com"
GREENGRASS_VERSION="2.12.0"
REGION="eu-central-1"
iotRoleAlias="DevGreengrassCoreTokenExchangeRoleAlias"
THING_NAME="DevIoTDevice1"

DL_GW_COMPONENT="com.aggreko.dl.gs"
DL_GW_VERSION="1.0.3"
DL_GW_ARTIFACT="docker-compose-ipc.yml"
DL_GW_RECIPE=$DL_GW_COMPONENT"-"$DL_GW_VERSION".json"

#******************* Script ********************#
log "Startup script started"

if [ -f $DOCKER_FILE ]; then
   echo "File $DOCKER_FILE exists."

#disable the external repo to be able to install the RPM
 log "disable external repos"
 sed -i "s/enabled=1/enabled=0/" /etc/yum.repos.d/*.repo


   #install docker
   log "Installing docker"
   installDocker

   log "install utilities"
   installUtilities
   
   cp /root/extras/docker.socket /etc/systemd/system/
   cp /root/extras/docker.service /etc/systemd/system/
   systemctl daemon-reload
   systemctl enable docker.service
   
   log "Docker installed"
 
 
   log "disable selinux"
   sed -i "s/SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config
 
    #Java config
   log "Configuring Java"
   configJava
   log "Java configured"


   rm -f $DOCKER_FILE
   systemctl reboot
elif [ -f $USER_FILE ]; then
  
   # create ggc_user and ggc_group
   log "Creating ggc_user and ggc_group"
   #configFixedIP
   createGgcUser  
   log "ggc_user and ggc_group created"


   log "Installing GreenGrass core"
   installGreenGrassCore
   log "GreenGrass core installed"
   
   log "Installing Greengrass-cli and other components"
   installGreenGrassComponents
   log "GreenGrass installed !"

   rm -f $USER_FILE
   terminateStartupService 
else
   terminateStartupService
fi

