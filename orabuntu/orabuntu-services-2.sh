#!/bin/bash

#    Copyright 2015-2019 Gilbert Standen
#    This file is part of Orabuntu-LXC.

#    Orabuntu-LXC is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.

#    Orabuntu-LXC is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Orabuntu-LXC.  If not, see <http://www.gnu.org/licenses/>.

#    v2.4 		GLS 20151224
#    v2.8 		GLS 20151231
#    v3.0 		GLS 20160710 Updates for Ubuntu 16.04
#    v4.0 		GLS 20161025 DNS DHCP services moved into an LXC container
#    v5.0 		GLS 20170909 Orabuntu-LXC Multi-Host
#    v6.0-AMIDE-beta	GLS 20180106 Orabuntu-LXC AmazonS3 Multi-Host Docker Enterprise Edition (AMIDE)

#    Note that this software builds a containerized DNS DHCP solution (bind9 / isc-dhcp-server).
#    The nameserver should NOT be the name of an EXISTING nameserver but an arbitrary name because this software is CREATING a new LXC-containerized nameserver.
#    The domain names can be arbitrary fictional names or they can be a domain that you actually own and operate.
#    There are two domains and two networks because the "seed" LXC containers are on a separate network from the production LXC containers.
#    If the domain is an actual domain, you will need to change the subnet using the subnets feature of Orabuntu-LXC
#
#!/bin/bash

clear

echo ''
echo "=============================================="
echo "orabuntu-services-2.sh                        "
echo "                                              "
echo "Script creates the Oracle Linux container.    "
echo "=============================================="
echo ''
echo "=============================================="
echo "This script is re-runnable                    "
echo "=============================================="

sleep 5

clear

MajorRelease=$1
OracleRelease=$1$2
OracleVersion=$1.$2
Domain1=$3
Domain2=$4
MultiHost=$5
NameServer=$6
DistDir=$7

if [ -e /sys/hypervisor/uuid ]
then
	function CheckAWS {
        	cat /sys/hypervisor/uuid | cut -c1-3 | grep -c ec2
	}
	AWS=$(CheckAWS)
fi

function SoftwareVersion { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }

function GetUbuntuVersion {
	cat /etc/lsb-release | grep DISTRIB_RELEASE | cut -f2 -d'='
}
UbuntuVersion=$(GetUbuntuVersion)

function GetLXCVersion {
        lxc-create --version
}
LXCVersion=$(GetLXCVersion)

function GetMultiHostVar1 {
echo $MultiHost | cut -f1 -d':'
}
MultiHostVar1=$(GetMultiHostVar1)

function GetMultiHostVar2 {
echo $MultiHost | cut -f2 -d':'
}
MultiHostVar2=$(GetMultiHostVar2)

function GetMultiHostVar3 {
echo $MultiHost | cut -f3 -d':'
}
MultiHostVar3=$(GetMultiHostVar3)

function GetMultiHostVar4 {
echo $MultiHost | cut -f4 -d':'
}
MultiHostVar4=$(GetMultiHostVar4)

function GetMultiHostVar5 {
echo $MultiHost | cut -f5 -d':'
}
MultiHostVar5=$(GetMultiHostVar5)

function GetMultiHostVar6 {
echo $MultiHost | cut -f6 -d':'
}
MultiHostVar6=$(GetMultiHostVar6)

function GetMultiHostVar7 {
        echo $MultiHost | cut -f7 -d':'
}
MultiHostVar7=$(GetMultiHostVar7)

function GetMultiHostVar8 {
        echo $MultiHost | cut -f8 -d':'
}
MultiHostVar8=$(GetMultiHostVar8)

function GetMultiHostVar9 {
        echo $MultiHost | cut -f9 -d':'
}
MultiHostVar9=$(GetMultiHostVar9)

function GetMultiHostVar10 {
        echo $MultiHost | cut -f10 -d':'
}
MultiHostVar10=$(GetMultiHostVar10)
GRE=$MultiHostVar10

function CheckSystemdResolvedInstalled {
	sudo netstat -ulnp | grep 53 | sed 's/  */ /g' | rev | cut -f1 -d'/' | rev | sort -u | grep systemd- | wc -l
}
SystemdResolvedInstalled=$(CheckSystemdResolvedInstalled)

if [ -f /etc/lsb-release ]
then
        function GetUbuntuVersion {
                cat /etc/lsb-release | grep DISTRIB_RELEASE | cut -f2 -d'='
        }
        UbuntuVersion=$(GetUbuntuVersion)
fi
RL=$UbuntuVersion

if [ -f /etc/lsb-release ]
then
        function GetUbuntuMajorVersion {
                cat /etc/lsb-release | grep DISTRIB_RELEASE | cut -f2 -d'=' | cut -f1 -d'.'
        }
        UbuntuMajorVersion=$(GetUbuntuMajorVersion)
fi

if [ $SystemdResolvedInstalled -gt 0 ] && [ $UbuntuVersion != '16.04' ]
then
	echo ''
	echo "=============================================="
	echo "Restart Systemd-Resolved ...                  "
	echo "=============================================="
	echo ''

	sudo service systemd-resolved-helper restart
	echo ''
	sleep 5
	sudo service systemd-resolved status | tail -100
	echo ''
	sleep 5
	sudo service systemd-resolved-helper status
	
	echo ''
	echo "=============================================="
	echo "Done: Restart Systemd-Resolved.               "
	echo "=============================================="

	sleep 5

	clear
fi

SeedIndex=10
SeedPostfix=c$SeedIndex

function CheckHighestSeedIndexHit {
        sudo nslookup -timeout=1 oel$OracleRelease$SeedPostfix | grep -v '#' | grep Address | grep '10\.207\.29' | wc -l
}
HighestSeedIndexHit=$(CheckHighestSeedIndexHit)

while [ $HighestSeedIndexHit = 1 ]
do
	SeedIndex=$((SeedIndex+1))
	SeedPostfix=c$SeedIndex
	HighestSeedIndexHit=$(CheckHighestSeedIndexHit)
done
SeedPostfix=c$SeedIndex

echo ''
echo "=============================================="
echo "Establish sudo privileges ...                 "
echo "=============================================="
echo ''

sudo date

echo ''
echo "=============================================="
echo "Establish sudo privileges successful.         "
echo "=============================================="
echo ''

sleep 5

clear

echo ''
echo "=============================================="
echo "   Create the LXC Oracle Linux container      "
echo "                                              "
echo "    Note: Depends on download speed...        "
echo "    Patience at downloading packages !        "
echo "=============================================="
echo ''

# GLS 20180410 
# Band-aid needs better solution/root cause analysis.  HUB host DNS/DHCP LXC container picks up a "ghost" DHCP IP that has to be cleared by a stop/start before Oracle container comes up on GRE host.
# GLS 20180412 
# This is no longer needed.  Problem was the the lxc.net.ipv4 was commented out in the config for the nameserver which was causing DHCP addresses to be issued instead of static.
# sshpass -p $MultiHostVar9 ssh -qt -o CheckHostIP=no -o StrictHostKeyChecking=no $MultiHostVar8@$MultiHostVar5 "sudo -S <<< "$MultiHostVar9" lxc-stop -n $NameServer -k; sudo -S <<< "$MultiHostVar9" lxc-start -n $NameServer"

sleep 5

sudo lxc-create -n oel$OracleRelease$SeedPostfix -t oracle -- --release=$OracleVersion

if [ $(SoftwareVersion $LXCVersion) -ge $(SoftwareVersion "2.1.0") ]
then
	sudo lxc-update-config -c /var/lib/lxc/oel$OracleRelease$SeedPostfix/config
fi

echo ''
echo "=============================================="
echo "Create the LXC oracle container complete      "
echo "(Passwords are the same as the usernames)     "
echo "Sleeping 5 seconds...                         "
echo "=============================================="
echo ''

sleep 5

clear

echo ''
echo "=============================================="
echo "Extracting oracle-specific files to container."
echo "=============================================="
echo ''

sudo mkdir -p /var/lib/lxc/oel$OracleRelease$SeedPostfix 
cd /opt/olxc/"$DistDir"/orabuntu/archives
sudo tar -xvf /opt/olxc/"$DistDir"/orabuntu/archives/lxc-oracle-files.tar -C /var/lib/lxc/oel$OracleRelease$SeedPostfix --touch

sudo chown root:root /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/etc/dhcp/dhclient.conf
sudo chmod 644 /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/etc/dhcp/dhclient.conf
sudo sed -i "s/HOSTNAME=ContainerName/HOSTNAME=oel$OracleRelease$SeedPostfix/g" /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/etc/sysconfig/network
# sudo rm /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/etc/ntp.conf

if [ -n $Domain1 ]
then
        sudo sed -i "/orabuntu-lxc\.com/s/orabuntu-lxc\.com/$Domain1/g" /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/etc/NetworkManager/dnsmasq.d/local
	sudo sed -i "/orabuntu-lxc\.com/s/orabuntu-lxc\.com/$Domain1/g" /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/etc/dhcp/dhclient.conf
fi

if [ -n $Domain2 ]
then
        sudo sed -i "/consultingcommandos\.us/s/consultingcommandos\.us/$Domain2/g" /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/etc/NetworkManager/dnsmasq.d/local
	sudo sed -i "/consultingcommandos\.us/s/consultingcommandos\.us/$Domain2/g" /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/etc/dhcp/dhclient.conf
fi

echo ''
echo "=============================================="
echo "Extraction container-specific files complete  "
echo "=============================================="

sleep 5

clear

echo ''
echo "=============================================="
echo "Begin LXC container MAC address reset...      "
echo "=============================================="
echo ''

sudo cp /var/lib/lxc/oel$OracleRelease$SeedPostfix/config /var/lib/lxc/oel$OracleRelease$SeedPostfix/config.original.bak

function GetOriginalHwaddr {
	sudo cat /var/lib/lxc/oel$OracleRelease$SeedPostfix/config | grep hwaddr | tail -1 | sed 's/\./\\\./g'
}
OriginalHwaddr=$(GetOriginalHwaddr)
echo $OriginalHwaddr | sed 's/\\//g'

sudo cp -p /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/config.oracle.bak.oel$MajorRelease /var/lib/lxc/oel$OracleRelease$SeedPostfix/config.oracle

sudo sed -i "s/lxc\.network\.hwaddr.*/$OriginalHwaddr/" /var/lib/lxc/oel$OracleRelease$SeedPostfix/config.oracle
sudo cp -p /var/lib/lxc/oel$OracleRelease$SeedPostfix/config.oracle /var/lib/lxc/oel$OracleRelease$SeedPostfix/config

# sudo sed -i "s/lxc\.mount\.entry = \/dev\/lxc_luns/#lxc\.mount\.entry = \/dev\/lxc_luns/g" /var/lib/lxc/oel$OracleRelease$SeedPostfix/config

echo ''
echo "These should match..."
echo ''
sudo grep hwaddr /var/lib/lxc/oel$OracleRelease$SeedPostfix/config.original.bak | tail -1
sudo grep hwaddr /var/lib/lxc/oel$OracleRelease$SeedPostfix/config.oracle

sudo chmod 644 /var/lib/lxc/oel$OracleRelease$SeedPostfix/config

echo ''
echo "=============================================="
echo "LXC container MAC address reset complete.     "
echo "=============================================="

sleep 5

clear

echo ''
echo "=============================================="
echo "Legacy script cleanups...                     "
echo "=============================================="
echo ''

sudo cp -p /etc/network/if-up.d/openvswitch/lxcora00-pub-ifup-sw1 /etc/network/if-up.d/openvswitch/oel$OracleRelease$SeedPostfix-pub-ifup-sx1
sudo cp -p /etc/network/if-down.d/openvswitch/lxcora00-pub-ifdown-sw1 /etc/network/if-down.d/openvswitch/oel$OracleRelease$SeedPostfix-pub-ifdown-sx1

sudo sed -i 's/-sw1/-sx1/g' /var/lib/lxc/oel$OracleRelease$SeedPostfix/config

sudo ls -l /etc/network/if-up.d/openvswitch/oel$OracleRelease$SeedPostfix*
sudo ls -l /etc/network/if-down.d/openvswitch/oel$OracleRelease$SeedPostfix*

echo ''
echo "=============================================="
echo "Legacy script cleanups complete               "
echo "=============================================="

sleep 5

clear

echo ''
echo "=============================================="
echo "Ping test  google.com...                      "
echo "=============================================="
echo ''

ping -c 3 google.com

function CheckNetworkUp {
ping -c 3 google.com | grep packet | cut -f3 -d',' | sed 's/ //g'
}
NetworkUp=$(CheckNetworkUp)
n=1
while [ "$NetworkUp" !=  "0%packetloss" ] && [ "$n" -le 5 ]
do
NetworkUp=$(CheckNetworkUp)
n=$((n+1))
done

if [ "$NetworkUp" != '0%packetloss' ]
then
echo ''
echo "=============================================="
echo "Ping google.com not reliably pingable.        "
echo "Script exiting.                               "
echo "=============================================="
exit
else
echo ''
echo "=============================================="
echo "Ping google.com reliable.                     "
echo "=============================================="
echo ''
fi

sleep 5

clear

# if [ $MajorRelease -eq 7 ]
# then
# 	echo ''
# 	echo "=============================================="
# 	echo "Create LXC NTP service file...                "
# 	echo "=============================================="
# 	echo ''

# 	Wants=ntpd.service
# 	Before=ntpd.service

# 	sudo sh -c "echo '[Unit]'             	         		 		>  /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/etc/systemd/system/ntp.service"
# 	sudo sh -c "echo 'Description=ntp Service'					>> /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/etc/systemd/system/ntp.service"
# 	sudo sh -c "echo 'Wants=ntpd.service'						>> /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/etc/systemd/system/ntp.service"
# 	sudo sh -c "echo 'Before=ntpd.service'						>> /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/etc/systemd/system/ntp.service"
# 	sudo sh -c "echo ''								>> /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/etc/systemd/system/ntp.service"
# 	sudo sh -c "echo '[Service]'							>> /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/etc/systemd/system/ntp.service"
# 	sudo sh -c "echo 'Type=oneshot'							>> /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/etc/systemd/system/ntp.service"
# 	sudo sh -c "echo 'User=root'							>> /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/etc/systemd/system/ntp.service"
# 	sudo sh -c "echo 'RemainAfterExit=yes'						>> /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/etc/systemd/system/ntp.service"
# 	sudo sh -c "echo 'ExecStart=/usr/sbin/ntpd -x'					>> /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/etc/systemd/system/ntp.service"
# 	sudo sh -c "echo 'ExecStop=/bin/bash /usr/sbin/service /usr/sbin/ntpd stop'	>> /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/etc/systemd/system/ntp.service"
# 	sudo sh -c "echo ''								>> /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/etc/systemd/system/ntp.service"
# 	sudo sh -c "echo '[Install]'							>> /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/etc/systemd/system/ntp.service"
# 	sudo sh -c "echo 'WantedBy=multi-user.target'					>> /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/etc/systemd/system/ntp.service"

# 	sudo cat /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/etc/systemd/system/ntp.service

# 	echo ''
# 	echo "=============================================="
# 	echo "Created LXC NTP service file.                 "
# 	echo "=============================================="

# 	sleep 5

# 	clear
	
 	echo ''
 	echo "=============================================="
 	echo "Set NTP '-x' option in ntpd file...           "
 	echo "=============================================="
 	echo ''

#	sudo sed -i -e '/OPTIONS/{ s/.*/OPTIONS="-g -x"/ }' /etc/sysconfig/ntpd
 	sudo sed -i -e '/OPTIONS/{ s/.*/OPTIONS="-g -x"/ }' /var/lib/lxc/oel$OracleRelease$SeedPostfix/rootfs/etc/sysconfig/ntpd

	sleep 5

	clear
	
 	echo ''
 	echo "=============================================="
 	echo "Done: Set NTP '-x' option in ntpd file.       "
 	echo "=============================================="

# fi

 sleep 5

 clear

if [ $(SoftwareVersion $LXCVersion) -ge $(SoftwareVersion "2.1.0") ]
then
	sudo lxc-update-config -c /var/lib/lxc/oel$OracleRelease$SeedPostfix/config
fi

echo ''
echo "=============================================="
echo "Initialize LXC Seed Container on OpenvSwitch.."
echo "=============================================="

cd /etc/network/if-up.d/openvswitch
sudo sed -i "s/ContainerName/oel$OracleRelease$SeedPostfix/g" /var/lib/lxc/oel$OracleRelease$SeedPostfix/config

function CheckContainerUp {
sudo lxc-ls -f | grep oel$OracleRelease$SeedPostfix | sed 's/  */ /g' | egrep 'RUNNING|STOPPED'  | cut -f2 -d' '
}
ContainerUp=$(CheckContainerUp)

function CheckPublicIP {
sudo lxc-ls -f | sed 's/  */ /g' | grep oel$OracleRelease$SeedPostfix | cut -f3 -d' ' | sed 's/,//' | cut -f1-3 -d'.' | sed 's/\.//g'
}
PublicIP=$(CheckPublicIP)

# GLS 20151217 Veth Pair Cleanups Scripts Create

sudo chown root:root /etc/network/openvswitch/veth_cleanups.sh
sudo chmod 755 /etc/network/openvswitch/veth_cleanups.sh

# GLS 20151217 Veth Pair Cleanups Scripts Create End

echo ''
echo "=============================================="
echo "Starting LXC Seed Container for Oracle        "
echo "=============================================="
echo ''

# GLS 20180410 
# Band-aid needs better solution/root cause analysis.  HUB host DNS/DHCP LXC container picks up a "ghost" DHCP IP that has to be cleared by a stop/start before Oracle container comes up on GRE host.
# GLS 20180412 
# This is no longer needed.  Problem was the the lxc.net.ipv4 was commented out in the config for the nameserver which was causing DHCP addresses to be issued instead of static.
# sshpass -p $MultiHostVar9 ssh -qt -o CheckHostIP=no -o StrictHostKeyChecking=no $MultiHostVar8@$MultiHostVar5 "sudo -S <<< "$MultiHostVar9" lxc-stop -n $NameServer -k; sudo -S <<< "$MultiHostVar9" lxc-start -n $NameServer"

sleep 5

sudo sed -i 's/sw1/sx1/' /etc/network/if-up.d/openvswitch/oel$OracleRelease$SeedPostfix*
sudo sed -i 's/sw1/sx1/' /etc/network/if-down.d/openvswitch/oel$OracleRelease$SeedPostfix*
sudo sed -i 's/tag=10/tag=11/' /etc/network/if-up.d/openvswitch/oel$OracleRelease$SeedPostfix*
sudo sed -i 's/tag=10/tag=11/' /etc/network/if-down.d/openvswitch/oel$OracleRelease$SeedPostfix*
sudo sed -i "s/mtu = 1500/mtu = $MultiHostVar7/" /var/lib/lxc/oel$OracleRelease$SeedPostfix/config
sudo sed -i "s/MtuSetting/$MultiHostVar7/" 	 /var/lib/lxc/oel$OracleRelease$SeedPostfix/config

if [ $ContainerUp != 'RUNNING' ] || [ $PublicIP != 1020729 ]
then
	function CheckContainersExist {
	sudo ls /var/lib/lxc | grep -v $NameServer | grep oel$OracleRelease$SeedPostfix | sort -V | sed 's/$/ /' | tr -d '\n' | sed 's/^[ \t]*//;s/[ \t]*$//'
	}
	ContainersExist=$(CheckContainersExist)
	sleep 5
	for j in $ContainersExist
	do
        	# GLS 20160707 updated to use lxc-copy instead of lxc-clone for Ubuntu 16.04
        	# GLS 20160707 continues to use lxc-clone for Ubuntu 15.04 and 15.10

		if [ $UbuntuMajorVersion -ge 16 ]
        	then
        		function CheckPublicIPIterative {
				sudo lxc-info -n oel$OracleRelease$SeedPostfix -iH | cut -f1-3 -d'.' | sed 's/\.//g' | head -1	
        		}
        	fi
		PublicIPIterative=$(CheckPublicIPIterative)
		echo "Starting container $j ..."
		echo ''
		sudo lxc-start -n $j > /dev/null 2>&1
		i=1
		while [ "$PublicIPIterative" != 1020729 ] && [ "$i" -le 10 ]
		do
			echo "Waiting for $j Public IP to come up..."
			echo ''
			sleep 10
			PublicIPIterative=$(CheckPublicIPIterative)
			if [ $i -eq 5 ]
			then
			sudo lxc-stop -n $j > /dev/null 2>&1
			sudo /etc/network/openvswitch/veth_cleanups.sh oel$OracleRelease$SeedPostfix
			echo ''
			sudo lxc-start -n $j > /dev/null 2>&1
			fi
		sleep 1
		i=$((i+1))
		done
	done
	
	echo "=============================================="
	echo "LXC Seed Container for Oracle started.        "
	echo "=============================================="
	echo ''
	echo "=============================================="
	echo "Waiting for final container initialization.   " 
	echo "=============================================="
fi

echo ''
echo "==============================================" 
echo "Public IP is up on oel$OracleRelease$SeedPostfix"
echo ''
sudo lxc-ls -f
echo ''
echo "=============================================="
echo "Container Up.                                 "
echo "=============================================="

sleep 10

clear

function CheckSearchDomain1 {
        grep -c $Domain1 /etc/resolv.conf
}
SearchDomain1=$(CheckSearchDomain1)

if [ $SearchDomain1 -eq 0 ] && [ $AWS -eq 0 ]
then
        sudo sed -i '/search/d' /etc/resolv.conf
        sudo sh -c "echo 'search $Domain1 $Domain2 gns1.$Domain1' >> /etc/resolv.conf"
fi

echo ''
echo "=============================================="
echo "Container oel$OracleRelease$SeedPostfix ping test..."
echo "=============================================="
echo ''

if [ $SystemdResolvedInstalled -eq 1 ] && [ $UbuntuVersion != '16.04' ]
then
	        sudo service systemd-resolved restart
fi

function CheckNetworkUp {
ping -c 3 oel$OracleRelease$SeedPostfix.$Domain2 | grep packet | cut -f3 -d',' | sed 's/ //g'
}
NetworkUp=$(CheckNetworkUp)
n=1
while [ "$NetworkUp" !=  "0%packetloss" ] && [ "$n" -le 5 ]
do
NetworkUp=$(CheckNetworkUp)
n=$((n+1))
done

if [ $SystemdResolvedInstalled -eq 1 ] && [ $UbuntuVersion != '16.04' ]
then
	sudo service systemd-resolved restart > /dev/null 2>&1
	sleep 2
fi
ping -c 3 oel$OracleRelease$SeedPostfix.$Domain2

if [ "$NetworkUp" != '0%packetloss' ]
then
echo ''
echo "=============================================="
echo "Container oel$OracleRelease$SeedPostfix not pinging."
echo "=============================================="
else
echo ''
echo "=============================================="
echo "Container oel$OracleRelease$SeedPostfix is pingable."
echo "=============================================="
echo ''
fi

sleep 5

clear

echo ''
echo "=============================================="
echo "Testing connectivity to oel$OracleRelease$SeedPostfix..."
echo "=============================================="
echo ''
echo "=============================================="
echo "Output of 'uname -a' in oel$OracleRelease$SeedPostfix..."
echo "=============================================="
echo ''

sudo lxc-attach -n oel$OracleRelease$SeedPostfix -- uname -a

if [ $? -ne 0 ]
then
echo ''
echo "=============================================="
echo "lxc-attach is failing...see if selinux is set."
echo "Script exiting.                               "
echo "=============================================="
exit
fi
echo ''
echo "=============================================="
echo "Test lxc-attach oel$OracleRelease$SeedPostfix successful. "
echo "=============================================="

sleep 5

clear

echo ''
echo "==============================================" 
echo "Next script to run: orabuntu-services-3.sh    "
echo "=============================================="

sleep 5
