#!/bin/bash
# @author nycko (AKA Nicolas Escobar)
# @mail nyckopro [at] gmail [dot] com
# @license GNU/GPL


function select_choice {
	echo -n "select your choice: ";
	read OPTION;
	OPTION=$(egrep "^$OPTION" /tmp/$IPADDR-menu | awk '{print $2}');
}

function menu2 {
	VAR="";
	for LINE in `egrep "^$OPTION" /tmp/$IPADDR-system.cfg |  awk -F \= '{print $1}'`;do
		VAR=$(echo "$LINE" | awk -F "$OPTION." '{print $2}' | awk -F \. '{print $1}');
		if [ "$VAR_TMP" != "$VAR" ];then
			echo "$OPTION.$VAR";
		fi
		VAR_TMP=$VAR;
	done
}

function change_password {
	FLAG=0;
	while [ "$FLAG" -eq 0 ];do
		echo -n "new password: ";read PASSWORD;
		echo -n "repeat password: ";read PASSWORD2;

		if [ "$PASSWORD" == "$PASSWORD2" ];then
			FLAG=1;
		else
			echo "Password not match";
		fi
	done

	echo "cifrando...";
	NEWPASS=$(perl -e 'print crypt($ARGV[0], "Vv")' $PASSWORD);
	echo "sed -i 's|^$OPTION.*|$OPTION=$NEWPASS|' /tmp/$IPADDR-system.cfg " | bash

	return $?;
}

function change_value {
#	echo -n "
	VALUE=$(egrep "^$OPTION" /tmp/$IPADDR-system.cfg | awk -F \= '{print $2}');
	echo -n "The option $OPTION has the value: $VALUE. Change to: "; read NEWVALUE;
	echo "sed -i 's|^$OPTION.*|$OPTION=$NEWVALUE|' /tmp/$IPADDR-system.cfg" | bash 
	
	return $?;
}

function _error {
	if [ "$1" == 0 ];then
		echo "[DONE]";
	else
		echo "[FAIL]";
		exit;
	fi
}

#VAR's
USER="ubnt";

if [ "$1" == "-c" ];then
	OPTION=$2;
	IPADDR=$3;
else
	if [ "$1" == "" ];then
		echo "Error: Use $0 [-c command] IPADDR";
		exit;
	fi
	OPTION="";	
	IPADDR=$1;
fi

FLAG_CHANGES=0;
PASS="ubnt"; 	
PASS2="ubnt2";
PASS3="nycko";

if [ ! "$OPTION" ];then

	#get system.cfg
	echo -en "Getting system.cfg... ";
	expect get_config.exp $USER $IPADDR $PASS $PASS2 $PASS3 #>/dev/null
	_error $?;

	if [ "$?" != 0 ];then
		echo "Error get_config";
	fi

	#Menu
	awk -F \= '{print $1}' /tmp/$IPADDR-system.cfg | awk -F \. '{print $1}' | sort | uniq | cat -n | tr -d ' ' | tee /tmp/$IPADDR-menu
	select_choice;
	OPTION1=$OPTION;

	FLAG=0;
	while [ "$FLAG" -eq 0 ];do
		echo "->[$OPTION]";
		RES_MENU=$(menu2);
	
		if [ "$RES_MENU" == "" ];then
			FLAG=1;
			continue;
		fi
		echo $RES_MENU |tr ' ' '\n' | cat -n | tr -d ' ' | tee /tmp/$IPADDR-menu;
		select_choice;
	done
fi
case $OPTION in
	"users.1.password") 
			change_password;
			if [ "$?" -eq 0 ];then
				echo "password updated";
				FLAG_CHANGES=1;
			fi
			;;
	*)
		echo "Option finale is $OPTION";
		change_value;
		if [ "$?" -eq 0 ];then
			echo "Value changed";
			FLAG_CHANGES=1;
		fi
esac

if [ "$FLAG_CHANGES" -ne 0 ];then
	echo -n "Update config? [y/n] ";read UPDATE;

	if [[ "$UPDATE" == "y" || "$UPDATE" == "Y" ]];then
		echo -n "send config...";
		expect send_config.exp $USER $IPADDR $PASS $PASS2 $PASS3 >/dev/null	
		_error $?;		

		echo -n "updating...";
		expect set_changes.exp $USER $IPADDR $PASS $PASS2 $PASS3 
		_error $?;		
	fi
fi
