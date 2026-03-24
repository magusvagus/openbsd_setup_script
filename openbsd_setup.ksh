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

printf ">>> Setting up MAC randomization\n"
sleep 1
for ETH in "${ETH[@]}"; do
	if [[ -e "/etc/hostname.$ETH" ]]; then
		printf "inet autoconf lladdr rendom" > "/etc/hostname.$ETH"
		printf "[ OK ] File /etc/hostname.%s modified\n" "$ETH"
	fi
done

printf ">>> Enable Single user password protection? [y/n] "
sleep 1
while true; do
	read ANSWER
	if [[ $ANSWER == 'y' ]]; then
		sed -e '1,/^.*secure.*$/s/secure/insecure/' /etc/ttys > /tmp/temp.txt; 
		mv /tmp/temp.txt /etc/tty; 
		rm /tmp/temp.txt;
		printf "[ OK ] File /etc/ttys modified.\n"
		break
	elif [[ $ANSWER == 'n' ]]; then
		break
	else
		printf "[ ER ] Invalid input.\n"
	fi
done

printf ">>> Installing additional programs.\n"
sleep 1
pkg_add	\
	vim-9.1.1706-gtk3	\
	wget-1.25.0p0		\
	curl-8.16.0			\
	unzip-6.0p18		\
	fzf-0.65.2			\
	scrot-1.12.1		\
	xbanish-1.8p0		\
	keynav-0.20101014.3067p4v0	\
	qutebrowser-3.5.1	\
	cmus-2.12.0			\
	mpv-0.40.0			\
	mupdf-1.26.10		\
	feh-3.10.3			\
	ranger-1.9.4p0		\
	nnn-5.1				\
	links-1.03p0		\
	lynx-2.9.2			\
	wireshark-4.4.9		\
	tshark-4.4.14		\
	gcc-libs-8.4.0p28	\
	minicom-2.8			\
	httrack-3.48.21p3	\
	git-2.51.0 			\
	gdb-16.3			\
	iftop-1.0pre4p4		\
	sword-1.9.0p1		\
	gnupg-2.4.9			\
	mpd-0.24.5			\
	picom-11.2p0		\
	fastfetch-2.53.0	\
	htop-3.4.1			\
	btop-1.4.5			\
	bat-0.25.0			\
	lsd-1.1.5p2			\
	tree-0.62			\
	weechat-4.7.1		\
	rtorrent-0.15.7v0	\
	tor-0.4.8.21		\
	tor-browser-15.0.7	\
	xclip-0.13p1		\
	py3-pip-25.2		\
	py3-pipx-1.8.0		\
	neovim-0.11.4 		\
	clang-tools-extra-21.1.2	\ 
	py3-python-lsp-server-1.12.2	\ 

printf ">>> Installation complete.\n"
sleep 1
	
printf ">>> Setting up doas\n"
sleep 1
touch /etc/doas.conf
chown root:wheel /etc/doas.conf
chmod 0400 /etc/doas.conf

printf "[ OK ] File /etc/doas.conf created.\n"
sleep 1

printf "
permit persist keepenv :wheel
permit persist keepenv :%s
permit persist keepenv :users

permit nopass %s as root cmd /sbin/reboot
permit nopass %s as root cmd /sbin/init

# permit this command for slstatus to use volume indication
permit nopass %s as root cmd sndioctl args output.level
# display brightness permission in .kshrc
permit nopass %s as root cmd wsconsctl args display.brightness=" "$USER" "$USER" "$USER" "$USER" "$USER" \
> /etc/doas.conf

printf "[ OK ] File /etc/doas.conf modified.\n"
sleep 1

# update system
# apply syspatch
# update firmware
# installing programs
# afterboot setup
