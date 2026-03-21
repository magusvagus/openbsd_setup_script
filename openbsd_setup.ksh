#!/bin/ksh
TIMEOUT=0
LOOP="true"
WIFI=$(dmesg | grep Wireless) 

# list of ethernet interface names
set -A ETH	\
	"em0"	\
	"re0"	\
	"ix0"	\
	"nfe0"	\
	"fxp0"	\
	"sis0"	\
	"pcn0"	\
	"vr0"	\
	"xl0"	\

#test for root
if [[ "$(id -u)" -ne 0 ]]; then
	printf "[ ER ] Scrip must be run as root!\n";
	exit 1;
else
	printf "[ OK ] You are root\n";
fi

printf ">>> Testing network connection.\n"
sleep 1
while [[ $TIMEOUT -ne 3 ]]; do

	ping -c 3 -W 1 9.9.9.9 >/dev/null 2>&1
	if [[ $? -eq 0 ]]; then
		printf "[ !! ] Can't reach network, retrying...\n"
		sleep 1
		(( TIMEOUT++ ))

		if [[ $TIMEOUT -eq 3 ]]; then
			printf "[ !! ] Could not connect to network.\n"
			TIMEOUT=0
			break
		fi
	else
		printf "[ OK ] You are online.\n"
		break
	fi
done

printf ">>> Wireless setup\n"
sleep 1
if [[ -z $WIFI ]]; then
	printf "[ ER ] No WIFI detected\n"
else
	# extract interface name
	WIFI=$(echo "$WIFI" | awk '{print $1}')
	printf "[ OK ] WIFI detected, interface: %s, $WIFI\n"

	LOOP='true'
	while [[ $LOOP == 'true' ]]; do
		printf ">>> Scan or connect to WIFI? [y/n/s]\n"
		read ANSWER

		if [[ $ANSWER = "y" ]]; then
			printf ">>> Enter SSID: "
			read SSID
			printf ">>> Enter WPAKEY: "
			read WPAKEY
			ifconfig join $SSID wpakey $WPAKEY lladdr random
			printf ">>> Connecting...\n"
			sleep 1
			sh /etc/netstart $WIFI

			# test connection
			if ping -c 3 9.9.9.9 > /dev/null 2>&1; then
				printf "[ !! ] Can't reach network, retrying...\n"
				sleep 1
				(( TIMEOUT++ ))
			if [[ $TIMEOUT -eq 3 ]]; then
				printf "[ !! ] Could not connect to network.\n"
				TIMEOUT=0
			else
				# create hostname file
				printf "[ OK ] You are online.\n"

				printf ">>> Creating hostname file\n"
				sleep 1
				touch /etc/hostname.${WIFI}
				printf "ifconfig join \"%s\" wpakey \"%s\" lladdr random" "$SSID" "$WPAKEY\ndhcp" >> /etc/hostname.${WIFI}
				printf "[ OK ] hostfile.%s created.\n" "$WIFI"
				sleep 1

				printf ">>> Setting up MAC randomization\n"
				for ETH in "${ETH[@]}"; do
					if [[ -e "/etc/hostname.$ETH" ]]; then
						printf "inet autoconf lladdr rendom" > "/etc/hostname.$ETH"
						printf "[ OK ] File /etc/hostname.%s edited\n" "$ETH"
					fi
				done

				break
			fi


		elif [[ $ANSWER = "s" ]]; then
			ifconfig $WIFI scan | less
		elif [[ $ANSWER = "n" ]]; then
			break
		else
			printf "[ ER ] Invalid input.\n"
		fi
	done
fi


# add MAC adress for ethernet ranomization
# add passkey to single user mode

