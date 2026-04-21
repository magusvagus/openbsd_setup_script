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

# check file function (give full path)
function check_file
{
	if [[ -f "$1" ]]; then
		return 0
	else
		printf "[ !! ] File does not exist, creating %s" "$1"
		touch "$1"
		return 1
	fi
}


# print marked package list
function printu
{
	typeset _index

	_index=0

	for USR in "${USERS[@]}"; do
		if [[ "${SELECTU[$_index]}" == "false" ]]; then
			BOX=" "
		else
			BOX="X"
		fi

		((_index++))
		if [[ $(( $_index % 2 )) -eq 0 ]];then
			printf "[%s] %2d. %-25s" "$BOX" "$_index" "${USR%-*}"
			printf "\n"
		else
			printf "[%s] %2d. %-25s" "$BOX" "$_index" "${USR%-*}"
		fi
	done
	printf "\n"
}

function printl
{
	typeset _index

	_index=0

	for PAK in "${PACKAGES[@]}"; do
		if [[ "${SELECT[$_index]}" == "false" ]]; then
			BOX=" "
		else
			BOX="X"
		fi

		((_index++))
		if [[ $(( $_index % 2 )) -eq 0 ]];then
			printf "[%s] %2d. %-25s" "$BOX" "$_index" "${PAK%-*}"
			printf "\n"
		else
			printf "[%s] %2d. %-25s" "$BOX" "$_index" "${PAK%-*}"
		fi
	done
	printf "\n"
}


# #############
# CHEK FOR ROOT
# #############

if [[ "$(id -u)" -ne 0 ]]; then
	printf "[ ER ] Scrip must be run as root!\n";
	exit 1;
else
	printf "[ OK ] You are root\n";
	sleep 0.5
fi


# #################
# CHEK/ Create USER
# #################

# get created user/s
set -A USERS -- $(getent passwd | awk -F: '$3 >= 1000 && $7 != "/sbin/nologin" { print $1 }')

if [ "${#USERS[@]}" -eq 0 ]; then
    printf "[ ER ] No user detected"
	USR="false"
# ceck if user exist but script is run as root
elif [ "${#USERS[@]}" -eq 1 ]; then
    printf "[ !! ] One user detected"
	USR="true"
# ceck if current user is logged in
elif [ "${#USERS[@]}" -gt 1 ]; then
    printf "[ !! ] Multiple user detected"
	USR="multi"
fi   

if [[ "$USR" == "false" ]]; then
	printf ">>> Creating new user"

	printf ">>> Enter user name: "
	read USER_NAME
	USR_NAME=$USER_INPUT

	printf ">>> Set user password: "
	read PASSWORD
	adduser -unencrypted -batch "$USER_NAME" wheel $USER_NAME $PASSWORD
	printf "[ OK ] New user '%s' created\n" "$USER_INPUT"
	sleep 0.5

	set -A USERS -- $(getent passwd | awk -F: '$3 >= 1000 && $7 != "/sbin/nologin" { print $1 }')
fi

# ##################
# NETWORK CONNECTION
# ##################

printf ">>> Testing network connection.\n"
sleep 1
while [[ $TIMEOUT -ne 3 ]]; do

	ping -c 3 -W 1 9.9.9.9 >/dev/null 2>&1
	if [[ $? -eq 0 ]]; then
		printf "[ !! ] Can't reach network, retrying...\n"
		sleep 0.5
		(( TIMEOUT++ ))

		if [[ "$TIMEOUT" -eq 3 ]]; then
			printf "[ !! ] Could not connect to network.\n"
			sleep 0.5
			TIMEOUT=0
			break
		fi
	else
		printf "[ OK ] You are online.\n"
		sleep 0.5
		break
	fi
done


# ##############
# WIRELESS SETUP
# ##############

printf ">>> Wireless setup\n"
sleep 1
if [[ -z "$WIFI" ]]; then
	printf "[ ER ] No WIFI detected\n"
	sleep 0.5
else
	# extract interface name
	WIFI=$(echo "$WIFI" | awk '{print $1}')
	printf "[ OK ] WIFI detected, interface: %s, $WIFI\n"
	sleep 0.5

	LOOP='true'
	while [[ $LOOP == 'true' ]]; do
		printf ">>> Scan or connect to WIFI? [y/n/s]\n"
		read ANSWER

		if [[ "$ANSWER" = "y" ]]; then
			printf ">>> Enter SSID: "
			read SSID
			printf ">>> Enter WPAKEY: "
			read WPAKEY
			ifconfig join $SSID wpakey $WPAKEY lladdr random
			printf "[ !! ] Connecting...\n"
			sleep 0.5
			sh /etc/netstart $WIFI

			# test connection
			if ping -c 3 9.9.9.9 > /dev/null 2>&1; then
				printf "[ !! ] Can't reach network, retrying...\n"
				sleep 0.5
				(( TIMEOUT++ ))
			elif [[ "$TIMEOUT" -eq 3 ]]; then
				printf "[ !! ] Could not connect to network.\n"
				sleep 0.5
				TIMEOUT=0
			else
				# create hostname file
				printf "[ OK ] You are online.\n"
				sleep 0.5

				printf ">>> Creating hostname file\n"
				sleep 1
				touch /etc/hostname.${WIFI}
				printf "ifconfig join \"%s\" wpakey \"%s\" lladdr random" "$SSID" "$WPAKEY\ndhcp" >> /etc/hostname.${WIFI}
				printf "[ OK ] hostfile.%s created.\n" "$WIFI"
				sleep 0.5

				break
			fi

		elif [[ "$ANSWER" = "s" ]]; then
			ifconfig $WIFI scan | less
		elif [[ "$ANSWER" = "n" ]]; then
			break
		else
			printf "[ ER ] Invalid input.\n"
			sleep 0.5
		fi
	done
fi


# #################
# MAC RANDOMIZATION
# #################

printf ">>> Setting up MAC randomization\n"
sleep 1
for ETH in "${ETH[@]}"; do
	if [[ -e "/etc/hostname.$ETH" ]]; then
		printf "inet autoconf lladdr rendom" > "/etc/hostname.$ETH"
		printf "[ OK ] File /etc/hostname.%s modified\n" "$ETH"
		sleep 0.5
	fi
done

# #########################
# SINGLE USER MODE PASSWORD 
# #########################

printf ">>> Enable Single user password protection? [y/n] "
sleep 1
while true; do
	read ANSWER
	if [[ "$ANSWER" == 'y' ]]; then
		sed -e '1,/^.*secure.*$/s/secure/insecure/' /etc/ttys > /tmp/temp.txt; 
		mv /tmp/temp.txt /etc/tty; 
		printf "[ OK ] File /etc/ttys modified.\n"
		sleep 0.5
		break
	elif [[ "$ANSWER" == 'n' ]]; then
		break
	else
		printf "[ ER ] Invalid input.\n"
		sleep 0.5
	fi
done


# ###################
# INSTALLING PACKAGES
# ###################

printf ">>> Installing packages.\n"
sleep 1

set -A PACKAGES\
	"vim-9.1.1706-gtk3"\
	"wget-1.25.0p0"\
	"curl-8.16.0"\
	"unzip-6.0p18"\
	"fzf-0.65.2"\
	"scrot-1.12.1"\
	"xbanish-1.8p0"\
	"qutebrowser-3.5.1"\
	"cmus-2.12.0"\
	"mpv-0.40.0"\
	"mupdf-1.26.10"\
	"feh-3.10.3"\
	"ranger-1.9.4p0"\
	"nnn-5.1"\
	"links-1.03p0"\
	"lynx-2.9.2"\
	"wireshark-4.4.9"\
	"tshark-4.4.14"\
	"gcc-libs-8.4.0p28"\
	"minicom-2.8"\
	"httrack-3.48.21p3"\
	"git-2.51.0"\
	"gdb-16.3"\
	"iftop-1.0pre4p4"\
	"sword-1.9.0p1"\
	"gnupg-2.4.9"\
	"mpd-0.24.5"\
	"picom-11.2p0"\
	"fastfetch-2.53.0"\
	"htop-3.4.1"\
	"btop-1.4.5"\
	"bat-0.25.0"\
	"lsd-1.1.5p2"\
	"tree-0.62"\
	"weechat-4.7.1"\
	"rtorrent-0.15.7v0"\
	"tor-0.4.8.21"\
	"tor-browser-15.0.7"\
	"xclip-0.13p1"\
	"py3-pip-25.2"\
	"clang-tools-extra-21.1.2"\
	"py3-pipx-1.8.0"\
	"keynav-0.20101014.3067p4v0"\
	"py3-python-lsp-server-1.12.2"\
	"neovim-0.11.4"\
	"rsync-3.4.1-minimal" \

# create list equal to number of packets
set -A SELECT
while [[ "$INDEX" -lt "${#PACKAGES[@]}" ]]; do
	SELECT[$INDEX]="false"
	((INDEX++))
done
INDEX=0

printl

while true; do
	# change quit to skip
	printf ">>> Installing packages [Choose 1-%d], [a]ll, [s]kip, [i]install: " "${#PACKAGES[@]}"
	read ANSWER
	if [[ "$ANSWER" == "p" ]]; then
		printl

	elif [[ "$ANSWER" == "s" ]]; then
		printf "[ !! ] Skipping...\n"
		sleep 0.5
		break

	elif [[ "$ANSWER" == "i" ]]; then
		for SEL in "${SELECT[@]}"; do
			if [[ $SEL == "true" ]]; then
				pkg_add ${PACKAGES[$INDEX]}
				((INDEX++))
				printf "\n"
			else
				((INDEX++))
			fi
		done
		INDEX=0

		# check if selection wasnt empty
		CHECK="false"
		for SEL in "${SELECT[@]}"; do
			if [[ "$SEL" == "true" ]]; then
				CHECK="true"
			fi
		done

		if [[ "$CHECK" == "true" ]]; then
			printf "[ OK ] Installation finished.\n"
			break
		else
			print "[ ER ] No Packages chosen.\n"
		fi



	elif [[ "$ANSWER" == "a" ]]; then
		if [[ $ALL == "true" ]]; then
			while [[ $INDEX -lt "${#SELECT[@]}" ]]; do
				SELECT[$INDEX]="true"
				((INDEX++))
			done
			ALL="false"
			INDEX=0
		else
			while [[ $INDEX -lt "${#SELECT[@]}" ]]; do
				SELECT[$INDEX]="false"
				((INDEX++))
			done
			ALL="true"
			INDEX=0
		fi

		printl

	# check if input is an integer
	elif case $ANSWER in *[!0-9]*) false;; *) true;; esac; then
		# check if number input is in rane
		if [[ "$ANSWER" -le "${#PACKAGES[@]}" && "$ANSWER" -ge 1 ]]; then
			ANSWER=$(( $ANSWER - 1 ))

			# turn on or off
			if [[ "${SELECT[$ANSWER]}" == "true" ]]; then
				SELECT[$ANSWER]="false"
				printl
			else
				SELECT[$ANSWER]="true"
				printl
			fi

		else	
			printf "[ ER ] Invalid input.\n"
		fi

	else
		printf "[ ER ] Invalid input.\n"
	fi

	INDEX=0
done


printf "[ OK ] Installation complete.\n"
sleep 0.5


# ##########
# DOAS SETUP
# ##########

printf ">>> Setting up doas\n"
sleep 1
touch /etc/doas.conf
chown root:wheel /etc/doas.conf
chmod 0400 /etc/doas.conf

printf "[ OK ] File /etc/doas.conf created.\n"
sleep 0.5

printf "
permit persist keepenv :wheel
permit persist keepenv :%s
permit persist keepenv :users

permit nopass %s as root cmd /sbin/reboot
permit nopass %s as root cmd /sbin/init

# permit this command for slstatus to use volume indication
permit nopass %s as root cmd sndioctl args output.level
# display brightness permission in .kshrc
permit nopass %s as root cmd wsconsctl args display.brightness=" "$USERS[0]" "$USERS[0]" "$USERS[0]" "$USERS[0]" "$USERS[0]" \
> /etc/doas.conf

printf "[ OK ] File /etc/doas.conf modified.\n"
sleep 0.5


# ##############
# KERNEL OPTIONS
# ##############

printf ">>> Setting up Kernel options.\n"
sleep 1

touch /etc/sysctl.conf
printf "[ OK ] File /etc/sysctl.conf created.\n"
sleep 0.5

THREADS=$(sysctl hw.ncpu)
# delete everything from output up to the number of threads
THREADS=${THREADS##*=}
if [[ "$THREADS" -gt 1 ]]; then
	printf "[ !! ] Hyperthreading support detected.\n"
	sleep 0.5

	printf "
	# Enable hyperthreading
	# ---------------------
	hw.smt=1\n\n" \
	> /etc/sysctl.conf

	printf "[ OK ] Hyperthreading enabled.\n"
	sleep 0.5
else
	printf "[ !! ] System does not support hyperthreading, skipping...\n"
	sleep 0.5
fi

RAM=$(dmesg | grep mem | awk '{print $4}' | head -n 1)
MB=1048576
GB=1073741824
GB2=2147483648

if [[ "$RAM" -ge "$GB" ]]; then
	printf "[ !! ] Available memory: %d GB\n" "$(( $RAM / 1024 / 1024 / 1024 ))"
	sleep 0.5
elif [[ "$RAM" -ge "$MB" ]]; then
	printf "[ !! ] Available memory: %d MB\n" "$(( $RAM / 1024 / 1024 ))"
	sleep 0.5
fi

SHMALL=$(( $RAM / 4096 ))

if [[ "$RAM" -gt "$GB2" ]]; then
	SHMMAX=$GB2
	SHMMNI=2048
else
	SHMMAX=$(( $RAM / 2 ))
	SHMMNI=4096
fi

printf "
# Shared memory limits
# --------------------
kern.shminfo.shmall=%d
kern.shminfo.shmmax=%d
kern.shminfo.shmmni=%d\n\n" "$SHMALL" "$SHMMAX" "$SHMMNI" \
>> /etc/sysctl.conf

printf "
# semaphores
# ----------
# Maximum number of shared memory segments per process
# (default often 128–512). Limits how many distinct shared
# memory regions a single process can attach to.

# Shared memory segement per process
kern.shminfo.shmseg=1024\n\n" \
>> /etc/sysctl.conf

printf "[ OK ] Shared memory limits set.\n"
sleep 0.5

printf "
# maximum number of system V semapthores system-wide
# increase together 'semmmni' (1:2 ratio)
#default 60
kern.seminfo.semmns=4096

# Maximum number ofshared memory identifiers in system
kern.seminfo.semmni=2048\n\n" \
>> /etc/sysctl.conf

printf "[ OK ] Semaphores set.\n"
sleep 0.5

# adjust to number of available threads
if [[ $THREADS -ge 8 ]]; then
	MAXPROC=32768
	MAXFILES=$(( $MAXPROC * 8 ))
	MAXTHREAD=$(( $MAXPROC * 2 ))
elif [[ $THREADS -ge 4 ]]; then
	MAXPROC=16384
	MAXFILES=$(( $MAXPROC * 6 ))
	MAXTHREAD=$(( $MAXPROC * 2 ))
elif [[ $THREADS -ge 2 ]]; then
	MAXPROC=8192
	MAXFILES=$(( $MAXPROC * 4 ))
	MAXTHREAD=$(( $MAXPROC * 2 ))
elif [[ $THREADS -eq 1 ]]; then
	MAXPROC=2048
	MAXFILES=$(( $MAXPROC * 2 ))
	MAXTHREAD=$(( $MAXPROC * 1 ))
fi

printf "
# system processes
# ----------------
# note: maxfiles and maxthread have to be set
# accordingly when changing maxproc.

# general rule:
# maxfile = (4 to 8) x maxproc
# as each process can open multiple files
# maxthread = (2 x maxproc)
# as browsers and other programs create many threads

# number of allowed processes
kern.maxproc=%d

# number of maximum files
kern.maxfiles=%d
kern.maxfilesperproc=%d
kern.maxvnodes=%d

# number of maximum threads
kern.maxthread=%d\n\n" "$MAXPROC" "$MAXFILES" "$MAXFILES" "$MAXFILES" "$MAXTHREAD" \
>> /etc/sysctl.conf

printf "[ OK ] System processes set.\n"
sleep 0.5

# set based on available RAM
if [[ "$RAM" -gt "$(( $GB2 * 16 ))" ]]; then
	BUFFERCACHE=90
elif [[ "$RAM" -gt "$(( $GB2 * 8 ))" ]]; then
	BUFFERCACHE=70
elif [[ "$RAM" -gt "$(( $GB2 * 4 ))" ]]; then
	BUFFERCACHE=60
elif [[ "$RAM" -gt "$GB2" ]]; then
	BUFFERCACHE=40
else
	BUFFERCACHE=10
fi

printf "
# Buffer cache
# ------------
# percentage of physical memory used for the buffer cache
# (typical range 10%% - 90%%)

	kern.bufcachepercent=%d\n\n" "$BUFFERCACHE" \
>> /etc/sysctl.conf

printf "[ OK ] Buffer cache set.\n"
sleep 0.5


# For servers
# kern.maxvnodes=262144
# printf "[ OK ] Number of vnodes set.\n"
# sleep 0.5

#kern.somaxconn=1024
# printf "[ OK ] TCP listen queue depth set.\n"
# sleep 0.5


# ################
# POWER MANAGEMENT
# ################

printf ">>> Power management setup.\n"
sleep 1

rcctl enable apmd
rcctl set apmd flags -A
rcctl start apmd

printf "[ OK ] Power management set.\n"
sleep 0.5


# ###########
# STAFF GROUP
# ###########

printf ">>> Setting up 'staff' group limits.\n"
sleep 1

# TODO add additional step to check for file

# Define replacements as an array w/ hooks
# currently preset based on personal setup
set -A STAFF\
	":datasize-cur="\
	":datasize-max="\
	":maxproc-max="\
	":openfiles-cur="\
	":openfiles-max="\
	":stacksize-cur="\
	":maxproc-cur="\
	":ignorenologin"\
	":requirehome"\
	":tc="\

set -A VAR\
	"1536M"\
	"infinity"\
	"8192"\
	"4096"\
	"8192"\
	"32M"\
	"32M"\
	""\
	"@"\
	"default"\

file="/etc/login.conf"
tmpfile="/tmp/obsd_setup."
INDEX=0

line_num=$(grep -n 'staff:' $file)
line_num=$(printf "%s" "$line_num" | awk -F: '{print $1}')

target_line=$line_num
current_line=0

while IFS= read -r line; do
    current_line=$((current_line + 1))
	if [[ $current_line -gt $target_line && $current_line -lt $(( $target_line + 11 )) ]]; then
		printf '\t%s%s:\\\n' "${STAFF[$INDEX]}" "${VAR[$INDEX]}"
		((INDEX++))
	else
		printf '%s\n' "$line"
	fi
done < "$file" > "$tmpfile" && mv "$tmpfile" "$file"   

INDEX=0

printf "[ OK ] File /etc/login.conf modified.\n"
sleep 0.5


INDEX=0
if [[ "$USR" == "true" ]]; then
	usermod -G staff "$USERS[0]"
	printf "[ OK ] %s added to staff group.\n" "$USERS[0]"
	sleep 0.5
elif [[ "$USR" == "multi" ]]; then
	set -A SELECTU
	while [[ "$INDEX" -lt "${#USERS[@]}" ]]; do
		SELECTU[$INDEX]="false"
		((INDEX++))
	done
	INDEX=0

	printu

	# put in function
	while true; do
		# change quit to skip
		printf ">>> Select user/s [Choose 1-%d], [s]kip, [o]k: " "${#USERS[@]}"
		read ANSWER
		if [[ "$ANSWER" == "s" ]]; then
			printf "[ !! ] Skipping User selection...\n"
			sleep 0.5
			break

		elif [[ "$ANSWER" == "o" ]]; then
			for SELU in "${SELECTU[@]}"; do
				if [[ $SELU == "true" ]]; then
					usermod -G staff "${USERS[$INDEX]}"
					printf "[ OK ] User \"%s\" added to staff group" "${USERS[$INDEX]}"
					sleep 0.5
					((INDEX++))
					printf "\n"
				else
					((INDEX++))
				fi
			done
			INDEX=0

			# check if selection wasnt empty
			CHECK="false"
			for SEL in "${SELECTU[@]}"; do
				if [[ "$SEL" == "true" ]]; then
					CHECK="true"
				fi
			done

			if [[ "$CHECK" == "true" ]]; then
				printf "[ OK ] User/s chosen.\n"
				break
			else
				print "[ ER ] No User chosen.\n"
			fi

			printu

		# check if input is an integer
		elif case $ANSWER in *[!0-9]*) false;; *) true;; esac; then
			# check if number input is in rane
			if [[ "$ANSWER" -le "${#USERS[@]}" && "$ANSWER" -ge 1 ]]; then
				ANSWER=$(( $ANSWER - 1 ))

				# turn on or off
				if [[ "${SELECTU[$ANSWER]}" == "true" ]]; then
					SELECTU[$ANSWER]="false"
					printu
				else
					SELECTU[$ANSWER]="true"
					printu
				fi

			else	
				printf "[ ER ] Invalid input.\n"
			fi

		else
			printf "[ ER ] Invalid input.\n"
		fi

		INDEX=0
	done

else
	printf "[ !! ] Skipping: Adding user to staff group.\n"
fi

# ##################
# INSTALL PORTS TREE
# ##################

while true; do
	printf ">>> Install ports tree? [y]es, [n]o: "
	read ANSWER
	if [[ "$ANSWER" == "y" ]]; then
		cd /tmp
		ftp https://cdn.openbsd.org/pub/OpenBSD/"$USERS[0]"/ports.tar.gz
		cd /usr
		doas tar xzf /tmp/ports.tar.gz   
		printf "[ OK ] Ports tree installed.\n"
	elif [[ "$ANSWER" == "n" ]]; then
		printf "[ !! ] Skipping: Installing ports tree.\n"
		break
	else
		printf "[ ER ] Invalid input.\n"
	fi
done


# TODO
# set wsconsctl.conf (workstation console access)
# fix semaphores
# if files not present, check and create.
# intro screen
# create seperate options Laptop/Desktop/Server use
# add each setup step to a function
# update package list
# update system
# apply syspatch
# update firmware
# afterboot setup
