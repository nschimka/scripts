function check_facls {
   if ! getfacl "$1" 2> /dev/null | grep -q "$2" 2> /dev/null; then
	print_FAIL

	#Determine what message to print out. Name is the user or group name, and
	#search is a simplified version of the grep argument $2 to determine which
	#part they got incorrect
	is_own=$(echo $2 | head -c 2 | tail -c 1)
        if [ "$is_own" = "#" ]; then   
                name=$(echo $2 | awk -F ":" '{print $(NF)}')
                name=$(echo $name | sed "s/\\$/ /")
                search=$(echo $2 | awk -F ":" '{print $1}')
        else
                name=$(echo $2 | awk -F ":" '{print $(NF-1)}')
                search=$(echo $2 | awk -F ":" '{print $1}')
                if [ "$search" = "^default" ]; then
                         search=$search$(echo $2 | awk -F ":" '{print $2}')
                fi
        fi

	echo $search
	#Check if the ownership is correct
	if [ "$search" = "^# owner" ]; then
		echo " - Ownership of $1 not set to $name"
		return 1
	fi
	if [ "$search" = "^# group" ]; then
		echo " - Group ownership of $1 is not set to $name"
		return 1
	fi

	#Check if the basic permissions are correct
	if [ "$2" = "^user::rwx$" ]; then
		echo " - User permissions not set to "rwx" on $1"
		return 1
	fi
	if [ "$2" = "^group::rwx$" ]; then
		echo " - Group permissions not set to "rwx" on $1"
		return 1
	fi
	if [ "$2" = "^other::---$" ]; then
		echo " - Other permissions not set to "---" on $1"
		return 1
	fi

	#Check if the facls are correct
	if [ "$search" = "^user" ]; then
		echo " - No, or incorrect, user ACL set up for $name on $1"
		return 1
	fi
	if [ "$search" = "^defaultuser" ]; then			
		echo " - No, or incorrect, default user ACL set up for $name on $1"
		return 1
	fi
	if [ "$search" = "^group" ]; then 
		echo " - No, or incorrect, group ACL set up for $name on $1"
		return 1
	fi
	if [ "$search" = "^defaultgroup" ]; then
		echo " - No, or incorrect, default group ACL set up for $name on $1"
		return 1
	fi
   fi	 
}

check_facls "/BurnBook" "^# owner: root$"
check_facls "/PlasticSabotage" "^# owner: root$"
check_facls "/BurnBook" "^# group: The_Plastics$"
check_facls "/PlasticSabotage" "^# group: StudentActivities$"

check_facls "/BurnBook" "^user::rwx$"
check_facls "/PlasticSabotage" "^user::rwx$"
check_facls "/BurnBook" "^group::rwx$" 
check_facls "/PlasticSabotage" "^group::rwx$" 
check_facls "/BurnBook" "^other::---$"
check_facls "/PlasticSabotage" "^other::---$"

check_facls "/PlasticSabotage" "^user:Regina:---$"
check_facls "/PlasticSabotage" "^default:user:Regina:---$"
check_facls "/PlasticSabotage" "^user:Gretchen:---$"
check_facls "/PlasticSabotage" "^default:user:Gretchen:---$"
check_facls "/PlasticSabotage" "^user:Karen:---$"
check_facls "/PlasticSabotage" "^default:user:Karen:---$"
check_facls "/PlasticSabotage" "^group:Authority:---$"
check_facls "/PlasticSabotage" "^default:group:Authority:---$"
check_facls "/BurnBook" "^default:group:Authority:---$"
check_facls "/BurnBook" "^group:Authority:---$"
check_facls "/BurnBook" "^user:Gretchen:r-x$"
check_facls "/BurnBook" "^default:user:Gretchen:r-x$"
