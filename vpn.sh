#!/bin/bash
#This is a automatic installer for OpenVPN by saint
# ~~~~~~~~~~ Environment Setup ~~~~~~~~~~ #
	NORMAL=`echo "\033[m"`
	BLUE=`echo "\033[36m"` #Blue
	RED_TEXT=`echo "\033[31m"` #Red
	INTRO_TEXT=`echo "\033[32m"` #green and white text
	END=`echo "\033[0m"`
# ~~~~~~~~~~ Environment Setup ~~~~~~~~~~ #
#Checking for root
if [[ $EUID -ne 0 ]];
			then echo -e "Script must be run as root!"
				exit 1
	fi
install_ovpn () {
###Starting###
# OpenVPN setup and first user creation
#In this part we will make the directories needed
		echo "* tell me your name for the client cert"
		read -p "Client name: " -e -i client CLIENT
		echo -e "${INTRO_TEXT}* Starting the installation of your OpenVPN server${END}"
			cd /home/$USER
			apt-get update -y
			git clone https://github.com/OpenVPN/easy-rsa-old
			apt-get install openvpn -y
			mkdir /etc/openvpn/easy-rsa
			cp -r /home/$USER/easy-rsa-old/tree/master/easy-rsa/2.0 /etc/openvpn/easy-rsa/
			rm -rf /home/$USER/2.0
###Configuring###
#In this part we will configure the files
		echo -e "${RED_TEXT}* Please fill in the information as following${END}"
		echo "KEY_COUNTRY=? (US is default)"
		read COUNTRY
		echo "KEY_PROVINCE=? (CA is default)"
		read PROVINCE
		echo "KEY_CITY=? (SanFrancisco is default)"
		read CITY
		echo "KEY_ORG=? (ex: Company-name)"
		read ORG
		echo "KEY_EMAIL=? (ex: your@email.com)"
		read MAIL
		echo "KEY_EMAIL=? (ex: your@email.com)"
		read EMAIL
		echo "KEY_CN=? (ex: server.hostname.com)"
		read KEYCN
		echo "KEY_NAME=? (ex: server.hostname.com)"
		read KEYNAME
		echo "KEY_OU=? (ex: OrganisationUnitname)"
		read ORGNAME
##Stronger Encryption##
	sed -i 's|export KEY_SIZE=1024|export KEY_SIZE=2048|' /etc/openvpn/easy-rsa/2.0/vars
###Replacing###
	sed -i -e "s/KEY_COUNTRY=\"US\"/KEY_COUNTRY=$COUNTRY/" /etc/openvpn/easy-rsa/2.0/vars
	sed -i -e "s/KEY_PROVINCE=\"CA\"/KEY_PROVINCE=$PROVINCE/" /etc/openvpn/easy-rsa/2.0/vars
	sed -i -e "s/KEY_CITY=\"SanFrancisco\"/KEY_CITY=$CITY/" /etc/openvpn/easy-rsa/2.0/vars
	sed -i -e "s/KEY_ORG=\"Fort-Funston\"/KEY_ORG=$ORG/" /etc/openvpn/easy-rsa/2.0/vars
	sed -i -e "s/KEY_EMAIL=\"me@myhost.mydomain\"/KEY_EMAIL=$MAIL/" /etc/openvpn/easy-rsa/2.0/vars
	sed -i -e "s/KEY_EMAIL=mail@host.domain/KEY_EMAIL=$EMAIL/" /etc/openvpn/easy-rsa/2.0/vars
	sed -i -e "s/KEY_CN=changeme/KEY_CN=$KEYCN/" /etc/openvpn/easy-rsa/2.0/vars
	sed -i -e "s/KEY_NAME=changeme/KEY_NAME=$KEYNAME/" /etc/openvpn/easy-rsa/2.0/vars
	sed -i -e "s/KEY_OU=changeme/KEY_OU=$ORGNAME/" /etc/openvpn/easy-rsa/2.0/vars
####Clearing whichopensslcnf####
#This will allow it to properly detect the version of OpenSSL on your computer#
	sed -i "s/\[\[:alnum\:\]\]//" /etc/openvpn/easy-rsa/2.0/whichopensslcnf
###Clean all###
cd /etc/openvpn/easy-rsa/2.0
source /etc/openvpn/easy-rsa/2.0/vars
. /etc/openvpn/easy-rsa/2.0/clean-all
#build ca
. /etc/openvpn/easy-rsa/2.0/build-ca
#build server
. /etc/openvpn/easy-rsa/2.0/build-key-server server
# DH params
. /etc/openvpn/easy-rsa/2.0/build-dh
# Client
. /etc/openvpn/easy-rsa/2.0/build-key "$CLIENT"
# Let's configure the server
	cp /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz /etc/openvpn
		gunzip /etc/openvpn/server.conf.gz
####Editing server.conf####
IP=$(/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1 }')
	sed_exec=$(echo $IP | sed -i -e "s/;local a.b.c.d/local $IP/" /etc/openvpn/server.conf)
GW=$(route -n | grep 'UG[ \t]' | awk '{print $2}')
	sed -i -e "s/;push \"route 192.168.10.0 255.255.255.0\"/push \"route $GW 255.255.255.0\"/" /etc/openvpn/server.conf
	sed -i 's/;user nobody/user nobody/g' /etc/openvpn/server.conf
	sed -i 's/;group nogroup/group nogroup/g' /etc/openvpn/server.conf
####Moving keys and files####
cd /etc/openvpn/easy-rsa/2.0/keys
cp ca.crt ca.key dh2048.pem server.crt server.key /etc/openvpn
cd /etc/openvpn/
# Set the server configuration
sed -i 's/dh dh1024.pem/dh dh2048.pem/' server.conf
# Enable net.ipv4.ip_forward for the system
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
# Avoid a reboot
echo 1 > /proc/sys/net/ipv4/ip_forward
# Set iptables
#Working on a fix
# And finally, restart OpenVPN
/etc/init.d/openvpn restart
# Let's generate the client config
mkdir ~/ovpn-$CLIENT
cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf ~/ovpn-$CLIENT/$CLIENT.conf
cp /etc/openvpn/easy-rsa/2.0/keys/ca.crt ~/ovpn-$CLIENT
cp /etc/openvpn/easy-rsa/2.0/keys/$CLIENT.crt ~/ovpn-$CLIENT
cp /etc/openvpn/easy-rsa/2.0/keys/$CLIENT.key ~/ovpn-$CLIENT
####Editing $CLIENT.conf####
EXTIP=$(wget -qO- ifconfig.me/ip)
sed_exec=$(echo $EXTIP | sed -i -e "s/remote my-server-1 1194/$EXTIP 1194/" ~/ovpn-$CLIENT/$CLIENT.conf)
####finishing up####
cd ~/ovpn-$CLIENT
sed -i "s/cert client.crt/cert $CLIENT.crt/" $CLIENT.conf
sed -i "s/key client.key/key $CLIENT.key/" $CLIENT.conf
tar -czf ../ovpn-$CLIENT.tar.gz $CLIENT.conf ca.crt $CLIENT.crt $CLIENT.key
cd ~/
rm -rf ovpn-$CLIENT
echo ""
echo -e "${INTRO_TEXT}Finished!${END}"
echo ""
echo -e "${INTRO_TEXT}Your client config is at ~/ovpn-$CLIENT.tar.gz${END}"
break
}
client_ovpn () {
echo "* tell me your name for the client cert"
read -p "Client name: " -e -i client CLIENT
####Client Config####
. /etc/openvpn/easy-rsa/2.0/build-key "$CLIENT"
mkdir ~/ovpn-$CLIENT
cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf ~/ovpn-$CLIENT/$CLIENT.conf
cp /etc/openvpn/easy-rsa/2.0/keys/ca.crt ~/ovpn-$CLIENT
cp /etc/openvpn/easy-rsa/2.0/keys/$CLIENT.crt ~/ovpn-$CLIENT
cp /etc/openvpn/easy-rsa/2.0/keys/$CLIENT.key ~/ovpn-$CLIENT
####Editing $CLIENT.conf####
EXTIP=$(wget -qO- ifconfig.me/ip)
sed_exec=$(echo $EXTIP | sed -i -e "s/remote my-server-1 1194/$EXTIP 1194/" ~/ovpn-$CLIENT/$CLIENT.conf)
####finishing up####
cd ~/ovpn-$CLIENT
sed -i "s/cert client.crt/cert $CLIENT.crt/" $CLIENT.conf
sed -i "s/key client.key/key $CLIENT.key/" $CLIENT.conf
tar -czf ../ovpn-$CLIENT.tar.gz $CLIENT.conf ca.crt $CLIENT.crt $CLIENT.key
cd ~/
rm -rf ovpn-$CLIENT
echo ""
echo "Finished!"
echo ""
echo -e "${INTRO_TEXT}Your client config is at ~/ovpn-$CLIENT.tar.gz${END}"
break
}
showMenu () {
	echo -e "${INTRO_TEXT}###############################${END}"
	echo "1) Install OpenVPN"
        echo "2) Add Clients"
        echo "3) quit"
	echo -e "${INTRO_TEXT}###############################${END}"
	echo ""
}
while [ 1 ]
do
        showMenu
        read CHOICE
        case "$CHOICE" in
                "1") install_ovpn ;;
                "2") client_ovpn ;;
                "3") echo "Ok then!"
                        break
			;;
		*) break 
        esac
done
