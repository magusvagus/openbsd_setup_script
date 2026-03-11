#!/bin/ksh

#test for root
if [[ "$(id -u)" -ne 0 ]]; then
	printf "Scrip must be run as root!\n";
	exit 1;
else
	printf "you are root\n";
fi
