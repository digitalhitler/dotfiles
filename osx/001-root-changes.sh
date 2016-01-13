#!/bin/bash
#####
# Root user changes bundle

echo " * * * Running superuser tasks...";

MYUSERNAME=`whoami`;
#echo "$MYUSERNAME";
if [ ! $MYUSERNAME ]; then
	echo "Error: cannot detect current username. We're going out";
	exit 1;
fi;

echo " ! Get ready to enter root password!";

echo " * Adding current user to sudoers list...";
sudo echo "$MYUSERNAME    ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers;
sudo chpass -s /usr/local/bin/fish $MYUSERNAME;

bash ./osx/sudo-brew-repair.sh;

echo " * * * Superuser tasks completed.";
