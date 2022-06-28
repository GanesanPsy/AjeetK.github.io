#!/bin/bash
#source $(dirname "$0")/helperfunc.sh
#source $(dirname "$0")/create_env.sh
#source $(dirname "$0")/errorhandler.sh
#source $(dirname "$0")/sync_dkp_data_Ellipse.sh
#source $(dirname "$0")/sync_dkp_data.sh
#source $(dirname "$0")/cleanup.sh
#source $(dirname "$0")/ingestion-setup.sh

function main1(){
    echo
    base64 -d 
    echo
    echo "                  M"
    echo
    echo "---------------------------------------------------------------------"
    echo "This script sets up an evaluation version of  in your environment."
    echo "---------------------------------------------------------------------"
    echo
    echo " Please ensure the following are set up before proceeding."
    echo " 1. Install Docker & Docker Compose"
    echo " 2. Install Git & obtain GitHub Personal Access Token"
    echo 
    read -p " Proceed? (y/n) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        exit 1
    fi

}


######  Calling Main Function #######
#main
main1


