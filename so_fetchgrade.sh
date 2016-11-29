#!/bin/bash
#
# Copyright 2014 Red Hat, Inc.
#
# NAME
#     so_fetchgrade - grading script for mean girls comprehensive review
#
# SYNOPSIS
#     so_fetchgrade (--help)
#
#     This script only works on desktopX.example.com.F
#
# DESCRIPTION
#     This script, based on singular argument, either does setup or
#     grading for the SAII Comprehensive Review lab.
#
# CHANGELOG
#   * Wed Sep 10 2014 Scott McBrien <smcbrien@redhat.com>
#   - firewall check regex modified to remove beginning and end of line
#     anchors.  Anchors were returning FAILs in ROL since ROL also requires
#     port 5900/tcp be an added port exception.
#
#   * Mon Apr  7 2014 Wander Boessenkool <wboessen@redhat.com>
#   - original code

# Initialize and set some variables
MYHOST=""
CMD=""
DEBUG='true'
RUN_AS_ROOT='true'

# Source library of functions
LOG_FACILITY=local0
LOG_PRIORITY=info
LOG_TAG="${0##*/}"
DEBUG=false
ERROR_MESSAGE="Error running script. Contact your instructor if you continue \
to see this message."
PACKAGES=( bash )

# paths
LOGGER='/usr/bin/logger'
RPM='/bin/rpm'
SUDO='/usr/bin/sudo'

# Export LANG so we get consistent results
# For instance, fr_FR uses comma (,) as the decimal separator.
export LANG=en_US.UTF-8

# Read in GLS parameters if available
[ -r /etc/rht ] && . /etc/rht

# Set up exit handler (no need for user to do this)
trap on_exit EXIT

function log {

if [[ ${#1} -gt 0 ]] ; then
    $LOGGER -p ${LOG_FACILITY}.${LOG_PRIORITY} -t $LOG_TAG -- "$1"
else
    while read data ; do
        $LOGGER -p ${LOG_FACILITY}.${LOG_PRIORITY} -t $LOG_TAG -- "$1" "$data"   
    done
fi

}


function debug {

if [[ ${#1} -gt 0 ]] ; then
    msg="$1"

    if [[ "$DEBUG" = "true" ]] ; then
        echo "$msg"
    fi

    log "$msg"

else

    while read data ; do

        if [[ "$DEBUG" = "true" ]] ; then
            echo "$data"
        fi

        log "$data"

    done

fi

}


function on_exit {

status="$?"

if [[ "$status" -eq "0" ]] ; then
    exit 0
else
    DEBUG=true
    debug "$ERROR_MESSAGE"
    exit "$status"
fi

}


function check_root {

if [[ "$EUID" -gt "0" ]] ; then
    log 'Not running run as root = Fail'
    ERROR_MESSAGE='This script must be run as root!'
    exit 1
fi

}


function check_packages {

for package in ${PACKAGES[@]} ; do

    if $RPM -q $package &>/dev/null ; then
        continue
    else
        ERROR_MESSAGE="Please install $package and try again."
        exit 2

    fi
done

}


function confirm {

read -p "Is this ok [y/N]: " userInput

case "${userInput:0:1}" in
    "y" | "Y")
        return
        ;;
    *)
        ERROR_MESSAGE="Script aborted."
        exit 3
        ;;
esac

}


function check_host {

if [[ ${#1} -gt 0 ]]; then
    if [[ "$1" == "${HOSTNAME:0:${#1}}" ]]; then
        return
    else
        ERROR_MESSAGE="This script must be run on ${1}."
        exit 4
    fi
fi

}


function check_tcp_port {

if [[ ${#1} -gt 0 && ${#2} -gt 0 ]]; then
    # Sending it to the log always returns 0
    ($(echo "brain" >/dev/tcp/$1/$2)) && return 0
fi
return 1

}


function wait_tcp_port {

if [[ ${#1} -gt 0 && ${#2} -gt 0 ]]; then
    # Make sure it is pingable before we attempt the port check
    echo
    echo -n "Pinging $1"
    until `ping -c1 -w1 $1 &> /dev/null`;do
        echo -n "."
        sleep 3
    done

    iterations=0
    echo
    echo 'You may see a few "Connection refused" errors before it connects...'
    sleep 10
    until [[ "$remote_port" == "smart" || $iterations -eq 30 ]]; do
        ($(echo "brain" >/dev/tcp/$1/$2) ) && remote_port="smart" || remote_port="dumb"
        sleep 3
        iterations=$(expr $iterations + 1)
    done
    [[ $remote_port == "smart" ]] && return 0
fi
return 1

}


function push_sshkey {

if [[ ${#1} -gt 0 ]]; then
    rm -f /root/.ssh/known_hosts
    rm -f /root/.ssh/.labtoolkey
    rm -f /root/.ssh/.labtoolkey.pub
    (ssh-keygen -q -N "" -f /root/.ssh/.labtoolkey) || return 1
    (/usr/local/lib/labtool-installkey /root/.ssh/.labtoolkey.pub $1) && return 0
fi
return 1
    
}


function get_X {

  if [[ -n "${RHT_ENROLLMENT}" ]] ; then
    X="${RHT_ENROLLMENT}"
    MYHOST="${RHT_ROLE}"
  elif hostname -s | grep -q '[0-9]' ; then
    X="$(hostname -s | grep -o '[0-9]*')"
    MYHOST="$(hostname -s | grep -o '[^0-9]*')"
  else
    # If the short hostname does not have a number, it is probably localhost.
    return 1
  fi
  SERVERX="server${X}.example.com"
  DESKTOPX="desktop${X}.example.com"

  # *** The following variables are deprecated. Do not use them.
# TWO_DIGIT_X="$(printf %02i ${X})"
# TWO_DIGIT_HEX="$(printf %02x ${X})"
# LASTIPOCTET="$(hostname -i | cut -d. -f4)"
# # IPOCTETX should match X
# IPOCTETX="$(hostname -i | cut -d. -f3)"

  return 0

}


function get_disk_devices {

  # This functions assumes / is mounted on a physical partition,
  #   and that the secondary disk is of the same type.
  PDISK=$(df | grep '/$' | sed 's:/dev/\([a-z]*\).*:\1:')
  SDISK=$(grep -v "${PDISK}" /proc/partitions | sed '1,2d; s/.* //' |
          grep "${PDISK:0:${#PDISK}-1}.$" | sort | head -n 1)

  PDISKDEV=/dev/${PDISK}
  SDISKDEV=/dev/${SDISK}

}


function print_PASS() {
  echo -e '\033[1;32mPASS\033[0;39m'
}


function print_FAIL() {
  echo -e '\033[1;31mFAIL\033[0;39m'
}


function print_SUCCESS() {
  echo -e '\033[1;36mSUCCESS\033[0;39m'
}

# Additional functions for this shell script
function print_usage {
  cat << EOF
This script controls the grading of this lab.
Usage: grademe
       grademe -h|--help
EOF
}


function pad {
  PADDING="..............................................................."
  TITLE=$1
  printf "%s%s  " "${TITLE}" "${PADDING:${#TITLE}}"
}

function grade_cron {
  pad "Checking for correct crontab configuration";
  
  if ! crontab -u Gretchen -l 2> /dev/null | grep -E -q '0.*18.*\*.*\*.*1,3.*ls.*-[alZ][alZ][alZ].*\/BurnBook.*>.*\/home\/Gretchen\/Big_Hair\.txt'; then
    print_FAIL
    echo " - Gretchen's Cron job isn't configured correctly."
    return 1
  fi

  print_PASS
  return 0
}

function grade_makefiles {
  pad "Checking files in /PlasticSabotage"  

  if count_files '/PlasticSabotage' 'WhoIsWho-*' && count_files '/PlasticSabotage' 'DatingRules-*' &&
  count_files '/PlasticSabotage' 'WhatToWear-*'; then
  	print_PASS
  	return 0
  fi
  return 1
}

#natasha- fancy function to count files
function count_files {
	file_name=$(echo $2 | sed "s/-\*/ /")
	if (($(ls $1 2> /dev/null | grep $2 | wc -l) != 6)); then
		print_FAIL
		echo " - There are an incorrect number of $file_name files in $1"
		return 1
	fi
	
	return 0
}

function grade_graphical {
  pad "Checking that default mode is set to graphical"

  if ! systemctl get-default | grep -q 'graphical'; then
    print_FAIL
    echo " - Default mode is not set to graphical."
    return 1
  fi
  
  print_PASS
  return 0
}

function grade_hostname {
  pad "Checking that hostname is set to She-Doesnt-Even-Go-Here persistently"

  if ! hostnamectl | grep -q 'She-Doesnt-Even-Go-Here'; then
    print_FAIL
    echo " - Static hostname not configured corrrectly."
    return 1
  fi
  
  print_PASS
  return 0
}

function grade_authconfig {
  pad "Checking LDAP and Kerberos configuration"

  USER=ldapuser${X}
  grep -q "^${USER}:" /etc/passwd &> /dev/null
  RESULT=$?
  if [ ${RESULT} -eq 0 ]; then
    print_FAIL
    echo " - User ${USER} defined locally."
    return 1
  fi
  getent passwd ${USER} &> /dev/null
  RESULT=$?
  if [ ${RESULT} -ne 0 ]; then
    print_FAIL
    echo " - User ${USER} not available"
    return 1
  fi
  yum -y install krb5-workstation &> /dev/null
  RESULT=$?
  if [ ${RESULT} -ne 0 ]; then
    print_FAIL
    echo " - Could not install krb5-workstation package"
    return 1
  fi
  echo "kerberos" | kinit ${USER} &> /dev/null
  RESULT=$?
  if [ ${RESULT} -ne 0 ]; then
    print_FAIL
    echo " - Could not acquire credentials for ${USER}"
    return 1
  fi
  kdestroy &> /dev/null
  print_PASS
  return 0
}

function grade_autofs {
  pad "Checking automounted home directories"
  TESTUSER=ldapuser${X}
  TESTHOME=/home/guests/${TESTUSER}
  DATA="$(su - ${TESTUSER} -c pwd 2>/dev/null)"
  if [ "${DATA}" != "${TESTHOME}" ]; then
    print_FAIL
    echo " - Home directory not available for ${TESTUSER}"
    return 1
  fi
  if ! mount | grep '\/home\/guests' | grep -q nfs; then
    print_FAIL
    echo " - ${TESTHOME} not mounted over NFS"
    return 1
  fi
  if grep -q '\/home\/guests' /etc/fstab; then
    print_FAIL
    echo " - Guest home directories are not mounted from /etc/fstab"
    return 1
  fi

  print_PASS
  return 0
}

function grade_lv {
  pad "Checking for new VG, LV, and FS"

  read VG A A A A SIZE A <<< $(vgs --noheadings --units=m Cliques 2>/dev/null) &> /dev/null
  if [ "${VG}" != "Cliques" ]; then
    print_FAIL
    echo " - No Volume Group named 'Cliques' found"
    return 1
  fi

  if ! vgdisplay Cliques | grep 'PE Size' | grep -q '8\.00'; then
    print_FAIL
    echo " - Incorrect PE size on volume group Cliques"
    return 1
  fi

  read LV VG A SIZE A <<< $(lvs --noheadings --units=m Cliques 2>/dev/null | grep Geeks) &> /dev/null
  if [ "${LV}" != "Geeks" ]; then
    print_FAIL
    echo " - No LV named 'Geeks' found in VG 'Cliques'"
    return 1
  fi
  SIZE=$(echo ${SIZE} | cut -d. -f1)
  if  ! (( 600 < ${SIZE} && ${SIZE} < 1000 )); then
    print_FAIL
    echo " - Logical Volume 'Geeks' is not the correct size."
    return 1
  fi

  read LV VG A SIZE A <<< $(lvs --noheadings --units=m Cliques 2>/dev/null | grep Jocks) &> /dev/null
  if [ "${LV}" != "Jocks" ]; then
    print_FAIL
    echo " - No LV named 'Jocks' found in VG 'Cliques'"
    return 1
  fi
  SIZE=$(echo ${SIZE} | cut -d. -f1)
  if  ! (( 1300 < ${SIZE} && ${SIZE} < 1700 )); then
    print_FAIL
    echo " - Logical Volume 'Jocks' is not the correct size."
    return 1
  fi

  read LV VG A SIZE A <<< $(lvs --noheadings --units=m Cliques 2>/dev/null | grep Plastics) &> /dev/null
  if [ "${LV}" != "Plastics" ]; then
    print_FAIL
    echo " - No LV named 'Plastics' found in VG 'Cliques'"
    return 1
  fi
  SIZE=$(echo ${SIZE} | cut -d. -f1)
  if  ! (( 1800 < ${SIZE} && ${SIZE} < 2200 )); then
    print_FAIL
    echo " - Logical Volume 'Plastics' is not the correct size."
    return 1
  fi

  read DEV TYPE MOUNTPOINT <<< $(df --output=source,fstype,target /Successful 2> /dev/null | grep Successful 2> /dev/null) &> /dev/null
  if [ "${DEV}" != "/dev/mapper/Cliques-Geeks" ]; then
    print_FAIL
    echo " - Wrong device mounted on /Successful"
    return 1
  fi
  if [ "${TYPE}" != "vfat" ]; then
    print_FAIL
    echo " - Wrong file system type mounted on /Successful"
    return 1
  fi
  if [ "${MOUNTPOINT}" != "/Successful" ]; then
    print_FAIL
    echo " - Wrong mountpoint"
    return 1
  fi

  read DEV TYPE MOUNTPOINT <<< $(df --output=source,fstype,target /Gymnasium 2> /dev/null | grep Gymnasium 2> /dev/null) &> /dev/null
  if [ "${DEV}" != "/dev/mapper/Cliques-Jocks" ]; then
    print_FAIL
    echo " - Wrong device mounted on /Gymnasium"
    return 1
  fi
  if [ "${TYPE}" != "ext3" ]; then
    print_FAIL
    echo " - Wrong file system type mounted on /Gymnasium"
    return 1
  fi
  if [ "${MOUNTPOINT}" != "/Gymnasium" ]; then
    print_FAIL
    echo " - Wrong mountpoint"
    return 1
  fi

  read DEV TYPE MOUNTPOINT <<< $(df --output=source,fstype,target /IsButterACarb 2> /dev/null | grep IsButterACarb 2> /dev/null) &> /dev/null
  if [ "${DEV}" != "/dev/mapper/Cliques-Plastics" ]; then
    print_FAIL
    echo " - Wrong device mounted on /IsButterACarb"
    return 1
  fi
  if [ "${TYPE}" != "ext4" ]; then
    print_FAIL
    echo " - Wrong file system type mounted on /IsButterACarb"
    return 1
  fi
  if [ "${MOUNTPOINT}" != "/IsButterACarb" ]; then
    print_FAIL
    echo " - Wrong mountpoint"
    return 1
  fi
  print_PASS
  return 0
}

function grade_acls {
  pad "Checking ACLs"

  if ! [ -d /BurnBook ]; then
    print_FAIL
    echo " - Directory '/BurnBook' not found"
    return 1
  fi
  if ! [ -d /PlasticSabotage ]; then
    print_FAIL
    echo " - Directory '/PlasticSabotage' not found"
    return 1
  fi

  if check_facls "/BurnBook" "^# owner: root$" &&
  check_facls "/PlasticSabotage" "^# owner: root$" &&
  check_facls "/BurnBook" "^# group: The_Plastics$" &&
  check_facls "/PlasticSabotage" "^# group: StudentActivities$" &&
  check_facls "/BurnBook" "^user::rwx$" &&
  check_facls "/PlasticSabotage" "^user::rwx$" &&
  check_facls "/BurnBook" "^group::rwx$" &&
  check_facls "/PlasticSabotage" "^group::rwx$" &&
  check_facls "/BurnBook" "^other::---$" &&
  check_facls "/PlasticSabotage" "^other::---$" &&
  check_facls "/PlasticSabotage" "^user:Regina:---$" &&
  check_facls "/PlasticSabotage" "^default:user:Regina:---$" &&
  check_facls "/PlasticSabotage" "^user:Gretchen:---$" &&
  check_facls "/PlasticSabotage" "^default:user:Gretchen:---$" &&
  check_facls "/PlasticSabotage" "^user:Karen:---$" &&
  check_facls "/PlasticSabotage" "^default:user:Karen:---$" &&
  check_facls "/PlasticSabotage" "^group:Authority:---$" &&
  check_facls "/PlasticSabotage" "^default:group:Authority:---$" &&
  check_facls "/BurnBook" "^default:group:Authority:---$" &&
  check_facls "/BurnBook" "^group:Authority:---$" &&
  check_facls "/BurnBook" "^user:Gretchen:r-x$" &&
  check_facls "/BurnBook" "^default:user:Gretchen:r-x$"; then
	print_PASS
	return 0
  fi

  return 1
}

#natasha - fancy function to print out an error message for the appropriate facl error
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
   return 0 
}

function grade_packages {
  pad "Checking installed packages and services"

  if ! rpm -q httpd &> /dev/null; then
    print_FAIL
    echo " - 'httpd' must be installed"
    return 1
  fi
  if ! systemctl status httpd.service &> /dev/null; then
    print_FAIL
    echo " - httpd.service is not running"
    return 1
  fi
  if ! systemctl status httpd 2> /dev/null | grep -q '^[[:space:]]*Loaded.*enabled'; then
    print_FAIL
    echo " - httpd.service not set to be started at boot"
    return 1
  fi

  # check if more than one kernel is installed
  RESULT=$(rpm -q kernel | wc -l)
  if [ "${RESULT}" -eq 1 ]; then
    print_FAIL
    echo " - There is only one kernel package installed."
    return 1
  fi

  print_PASS
  return 0
}

#natasha - custom webserver grader that makes sure it's serving from the correct directory, that it's serving period, and that you've created a symbolic link to it in /root
function grade_webserver {
	pad "Checking if the webserver is working"

	if ! grep -q '^DocumentRoot.*"\/meatface"' /etc/httpd/conf/httpd.conf || ! grep -q '^<Directory.*"\/meatface"' /etc/httpd/conf/httpd.conf; then
		print_FAIL
		echo " - The webserver is not serving from /meatface"
		return 1
	fi	

	#derek - function to test if serving http://cloudjedi.org/starwars.html
	#natasha - checks to see if either downloaded image, TalentShow or GoHere, is being hosted on localhost
	if ! curl -v --silent localhost 2>&1 | grep -q 'img src=http:\/\/1.bp.blogspot.com\/-h9YR8f1KKlo\/UVlYW4mvhoI\/AAAAAAAAdos\/FSLqZcLWCbU\/s1600\/MeanGirls_152Pyxurz.jpg' && ! curl -v --silent localhost 2>&1 | grep -q 'img src=https:\/\/31.media.tumblr.com\/tumblr_m28diiVT8L1rsetzlo1_500.gif' ; then
		print_FAIL
		echo " - You aren't serving the correct webpage"
		return 1
	fi

	#Check the soft link
	if [ ! -e "YourMomsChestHair" ]; then
		print_FAIL
		echo " - 'YourMomsChestHair' doesn't exist"	
		return 1
	fi
	if [ ! -L "YourMomsChestHair" ]; then
		print_FAIL
		echo " - 'YourMomsChestHair' isn't a symbolic link"
		return 1
	fi
	if ! ls -l /root | grep -q 'YourMomsChestHair -> \/meatface'; then
		print_FAIL
		echo " - 'YourMomsChestHair' doesn't point to /meatface"
		return 1
	fi

	print_PASS
	return 0	
}

function grade_users {
  pad "Checking for correct user setup"

  if ! group_exists 'StudentActivities' || ! group_exists 'Authority' ||
  ! group_exists 'The_Plastics'; then
	return 1
  fi

  for USER in Gretchen Regina Karen Cady Damian Janis MrDuvall MsNorbury; do
    grep "$USER:x:.*" /etc/passwd &>/dev/null
    RESULT=$?
    if [ "${RESULT}" -ne 0 ]; then
      print_FAIL
      echo " - The user $USER has not been created."
      return 1
    fi 
  done

  for USER in Regina Gretchen Karen Cady; do
    grep "The_Plastics:x:.*$USER.*" /etc/group &>/dev/null
    RESULT=$?
    if [ "${RESULT}" -ne 0 ]; then
      print_FAIL
      echo " - The user $USER is not in the The_Plastics group."
      return 1
    fi  
  done
  for USER in Cady Damian Janis; do
    grep "StudentActivities:x:.*$USER.*" /etc/group &>/dev/null
    RESULT=$?
    if [ "${RESULT}" -ne 0 ]; then
      print_FAIL
      echo " - The user $USER is not in the StudentActivities group."
      return 1
    fi  
  done
  for USER in MrDuvall MsNorbury; do
    grep "Authority:x:.*$USER.*" /etc/group &>/dev/null
    RESULT=$?
    if [ "${RESULT}" -ne 0 ]; then
      print_FAIL
      echo " - The user $USER is not in the Authority group."
      return 1
    fi  
  done

  if ! primary_group 'Regina:' 'Regina' ||
  ! primary_group 'Gretchen:' 'Gretchen' ||
  ! primary_group 'Karen:' 'Karen' ||
  ! primary_group 'Cady:' 'Cady' ||
  ! primary_group 'Damian:' 'Damian' ||
  ! primary_group 'Janis:' 'Janis' ||
  ! primary_group 'Authority:' 'MrDuvall'; then
        return 1
  fi


  if ! check_passwd 'Regina' 'socialsuicide' ||
  ! check_passwd 'Gretchen' 'socialsuicide' ||
  ! check_passwd 'Karen' 'socialsuicide' ||
  ! check_passwd 'Cady' 'socialsuicide' ||
  ! check_passwd 'Damian' 'socialsuicide' ||
  ! check_passwd 'Janis' 'socialsuicide' ||
  ! check_passwd 'MrDuvall' 'winners' ||
  ! check_passwd 'root' 'PinkShirt'; then
	return 1
  fi

  if ! cat /etc/passwd | grep 'MrDuvall' | grep -q '2129'; then
    print_FAIL
    echo " - The user MrDuvall's uid is not set to 2129"
    return 1
  fi

  (LANG=C chage -l Gretchen | grep "Maximum number.*:.*30.*") &>/dev/null
  RESULT=$?
  if [ "${RESULT}" -ne 0 ]; then
    print_FAIL
    echo " - The Gretchen account must change passwords every 60 days."
    return 1
  fi

  for USER in Cady; do
    (LANG=C chage -l $USER | grep "Password expires" | grep "password must be changed") &>/dev/null
    RESULT=$?
    if [ "${RESULT}" -ne 0 ]; then
      print_FAIL
      cat << EOF
 - The user $USER must change the account password on next log in.
EOF
      return 1
    fi
  done

  if ! check_homedir 'Janis' '/home/evilstopper2' ||
  ! check_homedir 'Regina' '/home/queenbee' ||
  ! check_homedir 'Damian' '/home/evilstopper' ||
  ! check_homedir 'Karen' '/home/ImAMouseDuh'; then
	return 1
  fi

  print_PASS
  return 0
}

#natasha - customized function to check for primary group membership
function primary_group {
        groupid=$(grep $1 /etc/group | awk -F ":" '{print $(NF-1)}')
        primarygroupid=$(grep $2 /etc/passwd | awk -F ":" '{print $4}')
        if ! [ "$groupid" = "$primarygroupid" ]; then
            print_FAIL
            groupname=$(echo $1 | sed "s/:/./")
            echo " - The user $2 is not in the primary group $groupname"
            return 1
        fi
}

#natasha - consolidate group-existance checking
function group_exists {
	GROUP=$1
	grep $GROUP:x:* /etc/group &>/dev/null
	RESULT=$?
	if [ ${RESULT} -ne 0 ]; then
		print_FAIL
		echo " - The $GROUP group does not exist."
		return 1
	fi

	return 0
}

#natasha - consolidated homedir checking into a function
function check_homedir {
	USER=$1
	HOMEDIR=$2
	if ! cat /etc/passwd | grep $USER | grep -F -q $HOMEDIR; then
		print_FAIL
		echo " - $USER is not configured to use $HOMEDIR as home directory"
		return 1
	fi

	return 0 
}

#natasha - consolidated password checking into one function
function check_passwd {
    NEWPASS=$2
    USER=$1
    FULLHASH=$(grep "^$USER:" /etc/shadow | cut -d: -f 2)
    SALT=$(grep "^$USER:" /etc/shadow | cut -d'$' -f3)
    PERLCOMMAND="print crypt(\"${NEWPASS}\", \"\\\$6\\\$${SALT}\");"
    NEWHASH=$(perl -e "${PERLCOMMAND}")

    if [ "${FULLHASH}" != "${NEWHASH}" ]; then
      print_FAIL
      echo " - The password for user $USER is not set to ${NEWPASS}"
      return 1
    fi
    return 0
}

function grade_shareddir {
  pad "Checking for correct shared directory"
  
  #if [ $(stat -c %G /BurnBook) != "droids" ]; then
  #  print_FAIL
  #  echo " - /BurnBook does not have correct group ownership."
  #  return 1
  #fi

  if [ ! -d /BurnBook ]; then
     print_FAIL
     echo "- /BurnBook does not exist."
     return 1
  fi
  if [ ! -d /PlasticSabotage ]; then
     print_FAIL
     echo "- /PlasticSabotage does not exist."
     return 1
  fi

  if [ $(stat -c %a /BurnBook) -ne 3770 ]; then
    print_FAIL
    echo " - /BurnBook does not have correct permissions."
    return 1
  fi
  if [ $(stat -c %a /PlasticSabotage) -ne 2770 ]; then
    print_FAIL
    echo " - /PlasticSabotage does not have correct permissions."
    return 1
  fi

  print_PASS
  return 0
}

function grade_ssh {
  pad "Checking for correct ssh setup"

  grep '^.*PermitRootLogin.*no.*$' /etc/ssh/sshd_config &>/dev/null
  RESULT=$?
  if [ "${RESULT}" -ne 0 ]; then
    print_FAIL
    echo " - Root log in is still permitted with ssh."
    return 1
  fi

  print_PASS
  return 0
}

function grade_tz {
  pad "Checking for correct time and date settings"

  timedatectl | grep 'Africa/Johannesburg' &>/dev/null
  RESULT=$?
  if [ "${RESULT}" -ne 0 ]; then
    print_FAIL
    echo " - The timezone was not adjusted correctly."
    return 1
  fi

  if ! cat /etc/chrony.conf | grep -q 'server classroom\.example\.com'; then
    print_FAIL
    echo " - NTP is not set to synchronize from classroom.example.com"
    return 1
  fi

  print_PASS
  return 0
}

function grade_network {
  pad "Checking for correct network settings"

  if ! (nmcli con show |grep Fifth_Sense) &>/dev/null ; then
    print_FAIL
    echo " - The network connection Fifth_Sense does not exist."
    return 1
  fi

  (nmcli con show Fifth_Sense |grep ipv4.addresses |grep "ip *= *172\.25\.[[:digit:]]*\.10") &>/dev/null
  RESULT=$?
  if [ "${RESULT}" -ne 0 ]; then
    print_FAIL
    echo " - The ip address is not correct."
    return 1
  fi

  (nmcli con show Fifth_Sense |grep ipv4.dns |grep '172.25.254.254') &>/dev/null
  RESULT=$?
  if [ "${RESULT}" -ne 0 ]; then
    print_FAIL
    echo " - The DNS name server is incorrect."
    return 1
  fi

  (nmcli con show Fifth_Sense |grep connection.autoconnect |grep yes) &>/dev/null
  RESULT=$?
  if [ "${RESULT}" -ne 0 ]; then
    print_FAIL
    echo " - The Fifth_Sense network device is not configured to start on boot."
    return 1
  fi

  print_PASS
  return 0
}

# derek - done: for 24
function grade_rsync {
  pad "Checking for correct rsync backup"

  if [ ! -d /Fetch ]; then
    print_FAIL
    echo " - The target directory /Fetch does not exist."
    return 1
  fi

  rsync -avn /tmp /Fetch &>/dev/null
  RESULT=$?
  if [ "${RESULT}" -ne 0 ]; then
    print_FAIL
    echo " - Directory was not rsynced properly."
    return 1
  fi
  print_PASS
  return 0
}

# derek - done: for 25
function grade_tarcompress {
  pad "Checking for correct compressed archive"

  if [ ! -f /root/grool.tar.xz ]; then
    print_FAIL
    echo " - The /root/grool.tar.xz archive does not exist."
    return 1
  fi

  (tar tf /root/grool.tar.xz | grep 'lib') &>/dev/null
  RESULT=$?
  if [ "${RESULT}" -ne 0 ]; then
    print_FAIL
    echo " - The archive content is not correct."
    return 1
  fi
  print_PASS
  return 0
}

# derek - done: for 2
function grade_yumrepo {
  pad "Checking for correct yum repo setup"

  grep -R 'baseurl.*=.*content\.example\.com\/rhel7\.0\/x86\_64\/dvd' /etc/yum.repos.d/ &>/dev/null
  RESULT=$?
  if [ "${RESULT}" -ne 0 ]; then
    print_FAIL
    echo " - Check your yum repository again."
    return 1
  fi

  print_PASS
  return 0
}

function grade_mount {
  pad "Checking for correct mount"

  if [ ! -d /Successful ]; then
    print_FAIL
    echo " - The /Successful mount point does not exist"
    return 1
  fi
  if [ ! -d /Gymnasium ]; then
    print_FAIL
    echo " - The /Gymnasium mount point does not exist"
    return 1
  fi
  if [ ! -d /IsButterACarb ]; then
    print_FAIL
    echo " - The /IsButterACarb mount point does not exist"
    return 1
  fi

  grep '/Gymnasium' /proc/mounts &>/dev/null
  RESULT=$?
  if [ "${RESULT}" -ne 0 ]; then
    print_FAIL
    echo " - The disk is not mounted on /Gymnasium"
    return 1
  fi
  grep '/Successful' /proc/mounts &>/dev/null
  RESULT=$?
  if [ "${RESULT}" -ne 0 ]; then
    print_FAIL
    echo " - The disk is not mounted on /Successful"
    return 1
  fi
  grep '/IsButterACarb' /proc/mounts &>/dev/null
  RESULT=$?
  if [ "${RESULT}" -ne 0 ]; then
    print_FAIL
    echo " - The disk is not mounted on /IsButterACarb"
    return 1
  fi

  if ! grep -q '\/Successful' /etc/fstab; then
    print_FAIL
    echo " - /Successful is not mounted from /etc/fstab"
    return 1
  fi
  if ! grep -q '\/Gymnasium' /etc/fstab; then
    print_FAIL
    echo " - /Gymnasium is not mounted from /etc/fstab"
    return 1
  fi
  if ! grep -q '\/IsButterACarb' /etc/fstab; then
    print_FAIL
    echo " - /IsButterACarb is not mounted from /etc/fstab"
    return 1
  fi

  print_PASS
  return 0
}

function grade_cp {
  pad "Checking /root/ImAPusher has the correct files"

  if [ ! -d /root/ImAPusher ]; then
    print_FAIL
    echo " - The target directory /ImAPusher does not exist."
    return 1
  fi

  if find_files 'MsNorbury' 'jobapplications' '/root/ImAPusher' && 
  find_files 'MsNorbury' 'MsNorbury' '/root/ImAPusher' && 
  find_files 'MsNorbury' 'bestwinelist' '/root/ImAPusher' && 
  find_files 'MsNorbury' 'mathletes' '/root/ImAPusher'; then
  	print_PASS
  	return 0
  fi

  return 1
}

#natasha - consolidated file-finding into one function
function find_files {
	USER=$1
	FILE=$2
	DIR=$3
	if ! ls $DIR | grep -q $FILE; then
		print_FAIL
		echo " - $USER's $FILE was not copied properly."
		return 1
	fi

	return 0
}

function grade_selinux {
  pad "Checking selinux settings"

  if ! getenforce | grep -q 'Enforcing'; then
    print_FAIL
    echo " - selinux is not set to enforcing"
    return 1
  fi

  if ! cat /etc/selinux/config | grep '^SELINUX' | grep -q 'enforcing'; then
    print_FAIL
    echo " - selinux is not set to enforcing at boot"
    return 1
  fi

  print_PASS
  return 0
}

#natasha - check that authpriv errors of alert and higher are logged to /var/log/drama.log
function grade_rsyslog {
	pad "Checking rsyslog configuration"

	logger -p authpriv.alert "this is a test message you never woulda thought by yourself"
	if ! grep "this is a test message you never woulda thought by yourself$" /var/log/drama.log &> /dev/null; then
		print_FAIL
		echo " - /var/log/drama.log is not configured correctly"
		return 1
	fi

	print_PASS
	return 0
}

# end grading section

function lab_grade {
  FAIL=0
  grade_cron || (( FAIL += 1 ))
  grade_makefiles || (( FAIL += 1 ))
  grade_graphical || (( FAIL += 1 ))
  grade_hostname || (( FAIL += 1 ))
  grade_authconfig || (( FAIL += 1 ))
  grade_autofs || (( FAIL += 1 ))
  grade_lv || (( FAIL += 1 ))
  grade_acls || (( FAIL += 1 ))
  grade_packages || (( FAIL += 1 ))
  grade_webserver || (( FAIL += 1 ))
  grade_rsyslog || (( FAIL += 1 ))
  grade_users || (( FAIL += 1 ))
  grade_shareddir || (( FAIL += 1 ))
  grade_ssh || (( FAIL += 1 ))
  grade_tz || (( FAIL += 1 ))
  grade_network || (( FAIL += 1 ))
  grade_rsync || (( FAIL += 1 ))
  grade_tarcompress || (( FAIL += 1 ))
  grade_yumrepo || (( FAIL += 1 ))
  grade_mount || (( FAIL += 1 ))
  grade_cp || (( FAIL += 1 ))
  grade_selinux || (( FAIL += 1 ))
  echo
  pad "Overall result"
  if [ ${FAIL} -eq 0 ]; then
    print_PASS
    echo "Congratulations! You've passed all tests."
  else
    print_FAIL
    echo "You failed ${FAIL} tests, please check your work and try again."
  fi
}

# Main area

# Check if to be run as root (must do this first)
if [[ "${RUN_AS_ROOT}" == 'true' ]] && [[ "${EUID}" -gt "0" ]] ; then
  if [[ -x /usr/bin/sudo ]] ; then
    ${SUDO:-sudo} $0 "$@"
    exit
  else
    # Fail out if not running as root
    check_root
  fi
fi

get_X

# Branch based on short (without number) hostname
lab_grade 'desktop'
