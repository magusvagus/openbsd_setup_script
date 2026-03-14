#!/bin/ksh
TIMEOUT=0
LOOP="true"

#test for root
if [[ "$(id -u)" -ne 0 ]]; then
	printf "[ ER ] Scrip must be run as root!\n";
	exit 1;
else
	printf "[ OK ] You are root\n";
fi

prinf ">>> Testing network connection.\n"
while [[ $TIMEOUT -ne 3 ]]; do
	if [[ $TIMEOUT -eq 3 ]]; then
		printf "[ !! ] Could not connect to network.\n"
		continue;
	fi

	ping -c 1 -W 1 9.9.9.9 >/dev/null 2>&1
	if [[ $? -eq 0 ]]; then
		printf '[ OK ] You are online.'
	else
		printf "[ !! ] Can't reach network, retrying...\n"
		sleep 1
		(( TIMEOUT++ ))
	fi
done

# prinf ">>> Network setup.\n"
# while [[ $LOOP == 'true' ]]

