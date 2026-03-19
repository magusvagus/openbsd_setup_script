#!/bin/ksh
TIMEOUT=0
LOOP="true"
WIFI=$(dmesg | grep Wireless | awk '{print $1}')

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
				printf "[ OK ] You are online.\n"
				break
			fi

		elif [[ $ANSWER = "s" ]]; then
			ifconfig $WIFI scan | less
		elif [[ $ANSWER = "n" ]]; then
			break
		fi
	done
fi

# while [[ $LOOP == 'true' ]]

