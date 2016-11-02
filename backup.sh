#!/usr/bin/bash
#
#Creates a backup of any directory 

#Change these to get it to work for you, or select the option to input your own info
BACKUP_LOC="/home/student/Videos"
SAVE_LOC="/home/student/backups"
COMPRESSION="bzip2"     #supports bzip2, xz, gzip
ARCHIVE_NAME="vids"     #the date will be appended to this

#Does the backing-up
function backup {
        read -p "If you’d like to manually enter backup information, type yes; else type no: " OP
        if [ "$OP" = "y" ] || [ "$OP" = "yes" ]; then
                user_input
                fi
        while [ "$OP" != "y" ] && [ "$OP" != "yes" ] && [ "$OP" != "n" ] && [ "$OP" != "no" ]; do
                echo
                read -p "Please enter yes or no to continue: " OP
                done
        error_check

        if [ "$COMPRESSION" = "gzip" ]; then
                ARCHIVE_COMMAND="z"
                fi
        if [ "$COMPRESSION" = "bzip2" ]; then
                ARCHIVE_COMMAND="j"
                fi
        if [ "$COMPRESSION" = "xz" ]; then
                ARCHIVE_COMMAND="J"
                fi

        BACKUP=$ARCHIVE_NAME-$(date +%F)
        echo
        echo backing up $BACKUP_LOC in $SAVE_LOC as $BACKUP with $COMPRESSION...

        #Back up the directory by creating an archive of it, extracting it in the 
        #requested location, and deleting the archive
        one_dir_above=$(dirname $BACKUP_LOC)
        backup_dir=$(basename $BACKUP_LOC)
        cd $one_dir_above
        tar cf$ARCHIVE_COMMAND $BACKUP $backup_dir &> /dev/null
        cd $SAVE_LOC
        tar xf$ARCHIVE_COMMAND $one_dir_above/$BACKUP &> /dev/null
        rm $one_dir_above/$BACKUP &> /dev/null
        mv $backup_dir $BACKUP
        echo done!
}

#If the user doesn't want to alter the variables at the top, here they enter in
#what they want to back up, where, how, and with what name
function user_input {
        read -p "Enter the location/file you want to back up: " BACKUP_LOC
        read -p "Enter where you’d like it to be saved: " SAVE_LOC
        read -p "Enter the compression type (bzip2, xz, gzip): " COMPRESSION
        read -p "Enter what you’d like to name the archive: " ARCHIVE_NAME
}

#Verifies that the values of all variables are valid
function error_check {
        echo
        while [ ! -d "$BACKUP_LOC" ]; do
                echo Error: backup location does not exist.
                read -p "Please enter a backup location: " BACKUP_LOC
                done
        while [ -z "$BACKUP_LOC" ]; do
                echo Error: no backup location given.
                read -p "Please enter a backup location: " BACKUP_LOC
                done
        if [ ! "$(ls -A $BACKUP_LOC)" ]; then
                echo Error: this directory contains no files to backup.
                echo Exiting.
                exit
                fi

        #If the directory where you want to save the backup doesn't exist, this will
        #make it for you as long as you have permission to make it
        if [ ! -d "$SAVE_LOC" ]; then
                echo Creating $SAVE_LOC ...
                mkdir $SAVE_LOC 2> direrror.txt
                while [ -s direrror.txt ]; do
                read -p "Error, cannot make directory. Enter another location: " SAVE_LOC
                        mkdir $SAVE_LOC 2> direrror.txt
                        done
                rm direrror.txt 2> /dev/null
                fi

        while [ -z "$SAVE_LOC" ]; do
                echo Error: no save location given
                read -p "Please enter a location to save your backup: " SAVE_LOC
                done
        while [ "$COMPRESSION" != "gzip" ] && [ "$COMPRESSION" != "bzip2" ] && [ "$COMPRESSION" != "xz" ]; do
                echo Error: must use gzip, bzip2, or xz.
                read -p "Please enter a valid compression type: " COMPRESSION
                done
        while [ -z "$ARCHIVE_NAME" ]; do
                echo Error: must give an archive name.
                read -p "Please enter an archive name: " ARCHIVE_NAME
                done
}

backup #runs the script
                               
