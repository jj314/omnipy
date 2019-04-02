#!/bin/bash


OMNIPY_HOME="/home/pi/omnipy"

function UpdateOmnipy(){
	cd $OMNIPY_HOME/../
	backupfilename="omnipy_backup_"$(date +%d-%m-%y-%H%M%S)".tar.gz omnipy"
	tar -cvzf $backupfilename
	cd $OMNIPY_HOME
	git stash
	git pull -f
	bash $OMNIPY_HOME/scripts/pi-update.sh
}

function NewPODActivation(){
		cd $OMNIPY_HOME
		echo "cd $OMNIPY_HOME"
		echo "./omni.py readpdm"
		whiptail --title "Activate new POD" --msgbox "The pi will enter in waiting after pressing the OK button.\nPress Status on your PDM within the next 10s to retreive the radio address." 15 80
		READPDM=$(./omni.py readpdm)
		#READPDM=$(cat readpdm.json)
		echo $READPDM
		STATUS=$(echo $READPDM | jq .success)
		echo $STATUS

		if [ $STATUS != "true" ]
		then 
			whiptail --title "POD Activation" --msgbox "A problem occured - Radio frequency cannot be retreived.\nNew pod activation aborted" 10 80
	 		MainMenu
		else		
			RadioAddress=$(echo $READPDM | jq .response.radio_address)
			whiptail --title "POD Activation" --msgbox "The radio address is $RadioAddress." 10 60
	
			LotID=$(whiptail --title "Input" --inputbox "What is the LOT Number ?" 10 60 3>&1 1>&2 2>&3)
	 		exitstatus=$?
			if [ $exitstatus -ne 0 ]; then MainMenu; fi;
	
			SerialID=$(whiptail --title "Input" --inputbox "What is the Serial Number ?" 10 60 3>&1 1>&2 2>&3)
	                exitstatus=$?
	                if [ $exitstatus -ne 0 ]; then MainMenu; fi;
	
	
			./omni.py newpod $LotID $SerialID $RadioAddress

		fi

}


function PODDeactivation(){

	if (whiptail --title "POD Deactivation?" --yesno "Are you sure you want to deactivate your POD ?" 10 60) then
	        whiptail --title "POD Deactivation" --msgbox "Don't forget to deactivate the POD on the PDM too !!!" 10 60
		cd ~
		cd omnipy
		echo "POD deactivation"
		./omni.py deactivate
        else
		whiptail --title "POD Deactivation" --msgbox "POD deactivation cancelled" 10 60
                echo "Deactivation cancelled"
       fi
}


function ConfigureRPi(){
	sudo raspi-config
	MainMenu
}


function ConfigureBT(){
    echo "Removing existing bluetooth devices"
    sudo btmgmt power on
    sudo bt-device -l | grep -e \(.*\) --color=never -o| cut -d'(' -f2 | cut -d')' -f1 | while read -r mac
    do
            if [ !mac ]; then
                    sudo bt-device -d $mac
                    sudo bt-device -r $mac
            fi
    done
    echo
    echo "Activating bluetooth pairing mode"
    sudo btmgmt connectable yes
    sudo btmgmt discov yes
    sudo btmgmt pairable yes
    sudo killall bt-agent
    sudo bt-agent -c NoInputNoOutput -d
    echo "Bluetooth device is now discoverable"
    echo
    echo "Open ${bold}bluetooth settings${normal} on your phone to search for and ${bold}pair${normal} with this device"
    echo "If you have already paired it on your phone, please unpair it first, then pair again"
    echo
    printf "Waiting for connection.."

    btdevice=
    while [[ -z "$btdevice" ]]
    do
            printf "."
            sleep 1
            btdevice=`sudo bt-device -l | grep -e \(.*\)`
    done

    sudo btmgmt discov no

    echo

    echo "${bold}Paired with $btdevice.${normal}"
    mac=`echo $btdevice | cut -d'(' -f2 | cut -d')' -f1`

    echo
    echo
    echo "Please ${bold}enable bluetooth tethering${normal} on your phone if it's not already enabled"
    echo "Waiting for connection."
    echo "addr=$mac" > /home/pi/omnipy/scripts/btnap-custom.sh
    cat /home/pi/omnipy/scripts/btnap.sh >> /home/pi/omnipy/scripts/btnap-custom.sh
    sudo cp /home/pi/omnipy/scripts/omnipy-pan.service /etc/systemd/system/
    sudo systemctl enable omnipy-pan.service
    sudo systemctl start omnipy-pan.service
    ipaddr=
    while [[ -z "$ipaddr" ]]
    do
            printf "."
            sleep 1
            ipaddr=`sudo ip -o -4 address | grep bnep0 | grep -e inet.*/ -o | cut -d' ' -f2 | cut -d'/' -f1`
    done
    echo
    echo
    echo "${bold}Connection test succeeeded${normal}. IP address: $ipaddr"

}





function DeveloperMenu(){
		echo "Developer Menu"
		SUBOPTION=$(whiptail --title "Advanced Settings" --menu "Choose the action you want to perform" --cancel-button "Back" 20 50 10 \
			"1" "Rig status" \
			"2" "View POD.log" \
			"3" "View omnipy.log" \
			"4" "Stop Services" \
			"5" "Restart Services" \
			"6" "Check RileyLink" \
			"7" "Configure Bluetooth" \
			"8" "Reset REST-API password" \
			"9" "Restore Omnipy backup" \
			"10" "Enable/Disable menu at SSH login"  3>&1 1>&2 2>&3)

		exitstatus=$?
		if [ $exitstatus -ne 0 ]; then MainMenu; fi;


		case $SUBOPTION in
			1)
				cd $OMNIPY_HOME
				echo "processing status..."
				RigStatus=$(./omni.py status)
				echo $RigStatus >> rigstatus.txt
				vim -R rigstatus.txt
				rm rigstatus.txt
				DeveloperMenu
			;;

			2)
				vim -R  ~/omnipy/data/pod.log
				DeveloperMenu
			;;

			3)
				vim -R ~/omnipy/data/omnipy.log
				DeveloperMenu
			;;

			4)
				echo "Stop services"
				sudo systemctl stop omnipy.service
				sudo systemctl stop omnipy-beacon.service
				sudo systemctl stop omnipy-pan.service
				
				Services_Status=

				if $(systemctl -q is-active omnipy.service)
				then
 					Services_Status="Failed: Omnipy Service has not been stopped\n"
				else
					Services_Status="Success: Omnipy Service has been stopped successfully\n"
				fi


				if $(systemctl -q is-active omnipy-beacon.service)
				then
                                        Services_Status+="Failed: Omnipy-beacon Service has not been stopped\n"
                                else
                                        Services_Status+="Success: Omnipy-beacon Service has been stopped successfully\n"
                                fi


				if $(systemctl -q is-active omnipy-pan.service)
				then
                                        Services_Status+="Failed: Omnipy-pan Service has not been stopped"
                                else
                                        Services_Status+="Success: Omnipy-pan Service has been stopped successfully"
                                fi

				whiptail --title "Omnipy Services stop " --msgbox "$Services_Status" 10 80
				DeveloperMenu
			;;

			5)
				echo "Restart services"
				sudo systemctl restart omnipy.service
				sudo systemctl restart omnipy-beacon.service
				sudo systemctl restart omnipy-pan.service


				Services_Status=

                                if $(systemctl -q is-active omnipy.service)
                                then
                                        Services_Status="Success: Omnipy Service has been restarted successfully\n"
                                else
                                        Services_Status="Failed: Omnipy Service has been not been restarted successfully\n"
                                fi


                                if $(systemctl -q is-active omnipy-beacon.service)
                                then
                                        Services_Status+="Success: Omnipy-beacon Service has been restarted successfully\n"
                                else
                                        Services_Status+="Failed: Omnipy-beacon Service has not been restarted successfully\n"
                                fi


                                if $(systemctl -q is-active omnipy-pan.service)
                                then
                                        Services_Status+="Success: Omnipy-pan Service has been restarted successfully"
                                else
                                        Services_Status+="Failed: Omnipy-pan Service has not been  restarted successfully"
                                fi

                                whiptail --title "Omnipy Services Restart " --msgbox "$Services_Status" 10 80
				DeveloperMenu
			;;

			6)
				echo "Verify RileyLink"
				python3 ~/omnipy/verify_rl.py
				DeveloperMenu
			;;
			7)
				echo "Configure Bluetooth"
				ConfigureBT
				DeveloperMenu

			;;
			8)
				echo "Reset REST-API password"
				/usr/bin/python3 /home/pi/omnipy/set_api_password.py
				DeveloperMenu

			;;

			9)
				echo "Restore Omnipy backup - to be done"
				cd ~
				ListofBackups=`for x in $(ls -1 *.gz); do echo $x "-"; done`

				if [ -z "$ListofBackups" ]
				then
					whiptail --title "Restore Backup"  --msgbox "There are no backup to restore" 20 80
					DeveloperMenu

				else
					OPTION=$(whiptail --title "Restore backup"  --menu "Select the backup you want to restore:" 20 80 10 $ListofBackups  3>&1 1>&2 2>&3)
					exitstatus=$?
					if [ $exitstatus -ne 0 ]; then exit; fi;

					cd ~
					mv omnipy omnipy_revert	
					tar -xvzf $OPTION

					whiptail --title "Restore Backup" --msgbox "Your pi will now reboot, please reconnect in a minute..." 20 80
	                                sudo reboot
				fi
			;;

			10)
				Linetoadd="~/omnipy/scripts/console-ui.sh"
                                Filetochange="~/.profile"

				if (whiptail --title "Menu autostart?" --yesno "Do you want menu to be loaded at logon ?" 10 60) then
					#Check if the ForceCommand exists and if not, modify /etc/ssh/sshd_config file by adding ForceCommand ./Scripts/console-ui.sh

					if grep -Fxq "$Linetoadd" $Filetochange
						then
							# code if found
							echo "Already activated"
						else
							# code if not found
							echo "Line added"
							sh -c "echo $Linetoadd >> $Filetochange"
							
					fi
				else
					#check if ForceCommand .$OMNIPY_HOME/scripts/console-ui.sh exits in /etc/ssh/sshd_config and it yes, remove it

					if grep -Fxq "$Linetoadd" $Filetochange
                                                then
                                                        # code if found
                                                        echo "Delete the line"
							sed -i "\#$Linetoadd#d" "$Filetochange"
							

                                                else
                                                        # code if not found
                                                        echo "Already deactivated"
                                        fi
				fi
				DeveloperMenu
			;;


		esac


}

function MainMenu(){

while true
do

#check if Menu autostart is enabled
ExitbuttonName="Back to Shell"

OPTION=$(whiptail --title "Omnipy Menu" --menu "Choose the action you want to perform" --cancel-button "$ExitbuttonName" 20 50 7  \
"1" "Activate New Pod" \
"2" "Deactivate Pod" \
"3" "Configure Raspberry Pi" \
"4" "Update Omnipy" \
"5" "Safe Reboot" \
"6" "Safe Shutdown" \
"7" "Advanced Settings" \
"8" "Log Out" 3>&1 1>&2 2>&3)

exitstatus=$?
if [ $exitstatus -ne 0 ]; then exit; fi;

case $OPTION in

	1) #Activate a new pod
		NewPODActivation
	;;
	
	2)
		PODDeactivation
		MainMenu

	;;
	

	3)
		ConfigureRPi

	;;

	4)
		echo "Update Omnipy"
                if(whiptail --title "Update Omnipy" --yesno "Do you want to update omnipy to the latest master branch ?" 8 45)
                        then
                                UpdateOmnipy
                        else
                                echo "Omnipy update cancelled"
                fi

	;;

	5)
		echo "Safe Reboot"
                if(whiptail --title "Safe Reboot" --yesno "Do you want to reboot your pi ? If yes, you'll need to reconnect..." 8 45)
                        then
                                sudo reboot
                        else
                                echo "Reboot cancelled"
                fi

	;;

	6)
		echo "Safe Shutdown"
                if(whiptail --title "Safe Shutdown" --yesno "Do you want to shutdown your pi ? If yes, to restart the pi, unplug and plug again the power supply..." 8 45)
                        then
                                sudo shutdown now
                        else
                                echo "Shutdown cancelled"
                fi
	;;

	7)
        DeveloperMenu
	
	;;

	8) 
		echo "Log Out"
                if(whiptail --title "Log Out" --yesno "Do you want to log off your pi ?" 8 45)
                        then
                                logout
                        else
                                echo "Shutdown cancelled"
                fi
esac

done
}

MainMenu
