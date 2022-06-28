#!/bin/bash
#source $(dirname "$0")/helperfunc.sh
#source $(dirname "$0")/create_env.sh
#source $(dirname "$0")/errorhandler.sh
#source $(dirname "$0")/sync_dkp_data_Ellipse.sh
#source $(dirname "$0")/sync_dkp_data.sh
#source $(dirname "$0")/cleanup.sh
#source $(dirname "$0")/ingestion-setup.sh
PROGNAME="$(basename $0)"
LOGFILE=$BASE_DIR/error.log

# Generates .env file and exports content
# so as to access as environment variables
load_env(){

    echo "Loading env file..."
    #Create env file
    if [[ -f $HOME/.env ]]; then
        echo ".env file exists."
    else
        echo "Generating .env file..."
        generate_env || throw $ERR_ENV
        echo "env file created!"
    fi

    # Exporting env file - Checks if already loaded, if not export
    [[ -z "${DKP_IMAGE_REGISTRY}" ]] && export $(grep -v '#.*' .env | xargs)

}

# Clones Repos from github
# Accepts 2 parameters
# 1. GIT Personal Access Token
# 2. Application array
clone_repos(){
    
    cd $HOME
    echo "Cloning git repositories...."
    local -n repoList=$2
    echo ""
    git config --global core.autocrlf false
    for i in "${repoList[@]}" ; do 
        repo_dir=`echo $i | awk -F'/' '{print $NF}' | awk -F'.' '{print $1}'` 
        if [[ -d $HOME/$repo_dir ]];
        then
            cd $HOME/$repo_dir
            git config --global --add safe.directory $HOME/$repo_dir
            git pull origin opensource
        else
            string_replace REPO_TEMP "$i" "$1"
            git clone -b opensource $REPO_TEMP --config core.autocrlf=false || throw $ERR_CLONE
        fi
        chown -R 1000:1000 $HOME/$repo_dir
        chmod +x *.sh || true
        cd $HOME
    done

}

#Building Docker images for applications
build_app(){

    #deploy_env=$1
    
    echo "Building Docker images...."
    local -n appList=$1
    for i in "${appList[@]}" ; do 
        cd $HOME/$i
        if [[ $i == "dkp-main-ui-view" ]]; then 
            docker build -f Dockerfile -t $DKP_IMAGE_REGISTRY/$i . || throw $ERR_DOCKER_BUILD
        elif [[ $i == "dkp-metadata" ]]; then
            docker build -t $DKP_IMAGE_REGISTRY/dkp-metadata-backend . || throw $ERR_DOCKER_BUILD
        elif [[ $i == "dkp-ellipse-ui-backend" ]]; then
            docker build -t $DKP_IMAGE_REGISTRY/dkp-ellipse-backend . || throw $ERR_DOCKER_BUILD
        elif [[ $i == "dkp-chatbot" ]]; then
            docker build -t $DKP_IMAGE_REGISTRY/dkp-chatbot-main . || throw $ERR_DOCKER_BUILD
        elif [[ $i == "dkp-data-orchestrator" ]]; then
            cd $HOME/$i/document-stores-sharepoint
            docker build -t $DKP_IMAGE_REGISTRY/document-stores-sharepoint . || throw $ERR_DOCKER_BUILD
        elif [[ $i == "dkp-ingestion-image-server" ]]; then
            cd $HOME/$DOCKER_COMPOSE_FOLDER/$i
            docker build -f Dockerfile-nginx -t $DKP_IMAGE_REGISTRY/$i . || throw $ERR_DOCKER_BUILD
        else
            docker build -t $DKP_IMAGE_REGISTRY/$i . || throw $ERR_DOCKER_BUILD
        fi
        echo "Building Docker image for $i is successful."
    done

}

# Deploys infra components
# Accepts 1 input - DEPLOYMENT_TYPE 1-Docker 2-K8
deploy_infra_components(){

    # Deploy Base Infra components
    # Redis, Zookeeper, Kafka and Elasticsearch
    echo "Deploying infra components...."
    cd $HOME
    case $1 in
    1)
        echo "Using Docker compose to deploy infra.."
        docker-compose -f docker-compose-infra.yml up -d || throw $ERR_DOCKER_COMPOSE_DEPLOY
        chown -R 1000:1000 $HOME
        chmod -R 755 $HOME
        ;;
    2)
        echo "Using kubectl to deploy infra..."
        echo "K8 deployment work in progress......."
        ;;
    esac
}

# Deploys Applications based on selection
# Accepts 2 inputs
# Input 1-DEPLOYMENT_TYPE (1-Docker,2-k8)
# Input 2-docker compose file name (If input 1 is docker)
deploy_app(){

    #Deploying infra based on DEPLOYMENT_TYPE
    deploy_infra_components $1

    echo "Deploying applications...."
    cd $HOME
    case $1 in
    1)
        echo "Using docker compose to deploy apps..."
        if [[ $3 == "" ]]; then
            docker-compose -f $2 up -d || throw $ERR_DOCKER_COMPOSE_DEPLOY
        else
            docker-compose -f $2 up -d $3 || throw $ERR_DOCKER_COMPOSE_DEPLOY
        fi
        
        ;;
    2)
        echo "Using kubectl to deploy apps..."
        echo "K8 deployment work in progress......."
        ;;
    esac
    #docker-compose up <service_name>
}

restart_containers(){
    docker-compose -f $1 restart || throw $ERR_DOCKER_COMPOSE_DEPLOY
}

handle_error(){
    echo "Failed during execution of step : $1"
}

error_exit(){
  echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
  exit 1
}

function main(){
    echo
    base64 -d <<<"H4sIAAAAAAAAA43TSw6AIAwE0D2nIGEzaYi9/+0MArblU+hO7YOpYox+pcW94AGkWrhFaawTKj1srN1rRI8C683zhIBsW6a0xLxB00CyAm8RQCPsHT4qRTWR7jgj28w+ihVBgQvUrwBmTTxEnTT0r1T1gEjPJMiEpM3Zay/CoCwRdwd2geSh/2uYeJfoG6R/sfACgoMtS68DAAA=" | gunzip
    echo
    echo "                   DATA AND KNOWLEDGE PLATFORM"
    echo
    echo "---------------------------------------------------------------------"
    echo "This script sets up an evaluation version of DKP in your environment."
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

    try 
    (
        echo "Checking prerequisites .... "
        
        if check_prerequisites
        then
            echo "Prerequisite check failed! Please install required software and run again."
            throw $ERR_EXIT
        fi

        read -p "Please enter the installation directory ( or press Enter for current directory - $PWD )": HOME_TEMP
        if [[ $HOME_TEMP == "" ]]; then
            HOME=$PWD
        else
            HOME=$HOME_TEMP
        fi

        #If install directory doesnt exist - create dir
        [ -d $HOME ] || mkdir -p $HOME

        export HOME=$HOME
        echo "DKP HOME directory: $HOME"

        if [[ "$BASE_DIR" == "$HOME" ]]; then
            echo
        else
            #Copying .sh,.yml to HOME directory to run the script.
            cp *.sh $HOME || true
        fi
        
        if [[ -f $HOME/.env ]]; then
            echo "Git Token loaded into env."
        else
            # Setting up GIT Token to clone repos
            if [[ $GIT_TOKEN=="" ]]; then
                read -sp "Please enter your GitHub Personal Access token (PAT): " GIT_TOKEN
                export GIT_TOKEN=$GIT_TOKEN
            else   
                echo "GIT PAT: $GIT_TOKEN"
            fi
        fi
        echo        
        echo
        echo

        # Generate env file and load environment variables
        #cp $BASE_DIR/.env $HOME
        cd $HOME
        load_env

        #Defaulting to Docker
        DEPLOYMENT_TYPE=1
        export DEPLOYMENT_TYPE=$DEPLOYMENT_TYPE
        cp $BASE_DIR/$DOCKER_COMPOSE_FOLDER/*.yml $HOME

        #To set a deployment type - Docker or K8
        # echo "Below are the available deployment options. "
        # deployment_type_list=("docker" "kubernetes")
        # echo "Please enter your choice: "
        # select deployment_type in "${deployment_type_list[@]}"; do
        #     [[ -n $deployment_type ]] || { echo "Invalid choice." >&2; continue; }
        #     DEPLOYMENT_TYPE=$deployment_type
        #     #export DEPLOYMENT_TYPE=$deployment_type
        #     case $REPLY in
        #     1)
        #         mkdir -p $HOME/$DOCKER_COMPOSE_FOLDER && cp -r $BASE_DIR/$DOCKER_COMPOSE_FOLDER $HOME
        #         ;;
        #     2)
        #         mkdir -p $HOME/$K8_FOLDER && cp -r $BASE_DIR/$K8_FOLDER $HOME
        #         ;;
        #     esac
        #     break
        # done

        # To Set up based on Environment DEV / PROD
        # Current setup set to PROD by default
        #
        # setup_env_list=("dev" "prod")
        # read -sp "Please enter your set up environment: " setup_type
        # select setup_type in "${setup_env_list[@]}"; do
        #     [[ -n $setup_type ]] || { echo "Invalid choice." >&2; continue; }
        #     # Setting to prod as default
        #     setup_type="prod"
        #     #setup_type=$setup_type
        #     #export setup_type=$setup_type
        #     break
        # done

        
        echo
        echo
        

        MAIN_UI_REPO_LIST=("$GIT_REPO_DKP_MAIN_UI_BACKEND" "$GIT_REPO_DKP_MAIN_UI_VIEW" "$GIT_REPO_DKP_RECOMMENDER" "$GIT_REPO_DKP_METADATA" "$GIT_REPO_DKP_METADATA_SERVICE_UI_VIEW" "$GIT_REPO_DKP_METADATA_SERVICE_UI_BACKEND" "$GIT_REPO_DKP_ACCESS_CONTROL" "$GIT_REPO_DKP_DATA_ORCHESTRATOR")
        main_ui_apps=("dkp-main-ui-backend" "dkp-main-ui-view" "dkp-recommender" "dkp-metadata" "dkp-metadata-services-ui-view" "dkp-metadata-services-ui-backend" "dkp-access-control" "dkp-data-orchestrator")

        ELLIPSE_REPO_LIST=("$GIT_REPO_DKP_ELLIPSE_UI_VIEW" "$GIT_REPO_DKP_ELLIPSE_UI_BACKEND" "$GIT_REPO_DKP_RECOMMENDER" "$GIT_REPO_DKP_METADATA" "$GIT_REPO_DKP_ACCESS_CONTROL")
        ellipse_apps=("dkp-ellipse-ui-view" "dkp-ellipse-ui-backend" "dkp-metadata" "dkp-access-control")

        METADATA_REPO_LIST=("$GIT_REPO_DKP_METADATA_SERVICE_UI_VIEW" "$GIT_REPO_DKP_METADATA_SERVICE_UI_BACKEND" "$GIT_REPO_DKP_RECOMMENDER" "$GIT_REPO_DKP_METADATA" "$GIT_REPO_DKP_CHATBOT" "$GIT_REPO_DKP_ACCESS_CONTROL")
        metadata_apps=("dkp-metadata-services-ui-view" "dkp-metadata-services-ui-backend" "dkp-metadata" "dkp-access-control")
        
        mainui_db_services="dkp-db-metadata dkp-db-main-ui-backend dkp-db-recommender dkp-db-metadata-services-ui-backend dkp-db-access-control"
        metdata_db_services="dkp-db-metadata dkp-access-control dkp-db-metadata-services-ui-backend"
        ellipse_db_services="dkp-db-ellipse dkp-db-metadata dkp-db-access-control"
        all_db_services="dkp-db-metadata dkp-db-main-ui-backend dkp-db-recommender dkp-db-metadata-services-ui-backend dkp-db-access-control dkp-db-ellipse"
        all_db_folders_list=("dkp-db-access-control-data" "dkp-db-ellipse-data" "dkp-db-metadata-data" "dkp-db-metadata-services-ui-backend-data" "dkp-db-recommender-data" "dkp-db-main-ui-backend-data" "redis_data_internal")


        ALL_REPOS=("${MAIN_UI_REPO_LIST[@]}" "${ELLIPSE_REPO_LIST[@]}" "${METADATA_REPO_LIST[@]}")
        all_apps=("${main_ui_apps[@]}" "${ellipse_apps[@]}" "${metadata_apps[@]}")

        #Removing Duplicates
        ALL_REPOS=($(printf "%s\n" "${ALL_REPOS[@]}" | sort -u | tr '\n' ' '))
        all_apps=($(printf "%s\n" "${all_apps[@]}" | sort -u | tr '\n' ' '))

        # Choose applications to clone and deploy
        echo " Below are the available applications. "
        apps=("DKP Central" "Ellipse" "Metadata Services" "All" "Exit")
        select APP_OPTION in "${apps[@]}"; do
            [[ -n $APP_OPTION ]] || { echo "Invalid choice." >&2; continue; }
            app_installed=$APP_OPTION
            case $REPLY in
            1)
                echo "DKP Central Application."
                clone_repos "$GIT_TOKEN" MAIN_UI_REPO_LIST
                build_app main_ui_apps
                deploy_app $DEPLOYMENT_TYPE docker-compose-main-ui-prod.yml
                #deploy_app $DEPLOYMENT_TYPE docker-compose-main-ui-prod.yml $mainui_db_services
                #add_permissions all_db_folders_list
                ingestion_setup $DKP_CENTRAL_APP 
                #deploy_app $DEPLOYMENT_TYPE docker-compose-main-ui-prod.yml
                #restart_containers docker-compose-main-ui-prod.yml
                #Metadata Indexing
                start_es_indexing
                ;;
            2)
                echo "Ellipse Application."
                clone_repos "$GIT_TOKEN" ELLIPSE_REPO_LIST
                build_app ellipse_apps
                deploy_app $DEPLOYMENT_TYPE docker-compose-ellipse-prod.yml
                #deploy_app $DEPLOYMENT_TYPE docker-compose-ellipse-prod.yml $ellipse_db_services
                cd $HOME
                #add_permissions all_db_folders_list
                ingestion_setup $ELLIPSE_APP
                #deploy_app $DEPLOYMENT_TYPE docker-compose-ellipse-prod.yml
                #restart_containers docker-compose-ellipse-prod.yml
                               
                #Metadata Indexing
                start_es_indexing
                ;;
            3)
                echo "Metadata Services UI Application."
                clone_repos "$GIT_TOKEN" METADATA_REPO_LIST
                build_app metadata_apps
                deploy_app $DEPLOYMENT_TYPE docker-compose-metadata-prod.yml
                #deploy_app $DEPLOYMENT_TYPE docker-compose-metadata-prod.yml $metdata_db_services
                #add_permissions all_db_folders_list
                ingestion_setup $METADATA_SERVICES_APP
                #deploy_app $DEPLOYMENT_TYPE docker-compose-metadata-prod.yml
                #restart_containers docker-compose-metadata-prod.yml
                #Metadata Indexing
                start_es_indexing
                ;;
            4)
                echo "All Applications."
                clone_repos "$GIT_TOKEN" ALL_REPOS
                build_app all_apps
                deploy_app $DEPLOYMENT_TYPE docker-compose.yml
                #add_permissions all_db_folders_list
                ingestion_setup $ALL_APPS
                #deploy_app $DEPLOYMENT_TYPE docker-compose.yml
                #restart_containers docker-compose.yml
                #Metadata Indexing
                start_es_indexing
                ;;
            5)
                echo "Exiting..."
                exit 0
                ;;
            esac

            break
        done
    ) 
    catch || {
        case $ERROR_CODE in
            $ERR_EXIT)
                echo "Error encountered during prerequisite check."
            ;;
            $ERR_ENV)
                echo "Error encountered during env file generation."
            ;;
            $ERR_CLONE)
                echo "Error encountered during cloning of repositories."
            ;;
            $ERR_DB_SYNC)
                echo "Error encountered during DB sync activity."
            ;;
            $ERR_DOCKER_BUILD)
                echo "Error encountered during Docker image build activity."
                #help_setup_docker_user
                #Do Clean up required
                #cleaup_build
            ;;
            $ERR_DOCKER_COMPOSE_DEPLOY)
                echo "Error encountered during app deployment."
                #Do Clean up required
                cleanup_deploy
                echo 
            ;;
            $ERR_DOWNLOAD)
                echo "Error while downloading the file."
                #Do Clean up required
            ;;
            *)
                echo "Unknown error: $ERROR_CODE"
                throw $ERROR_CODE    # re-throw an unhandled exception
            ;;
        esac
    }
    

    # Run Health check api test / Check corresponding deployments
    # Display UI urls based on host ip
    
}

BASE_DIR=$PWD
HOME=$BASE_DIR
export ERR_EXIT=100
export ERR_DOCKER_BUILD=101
export ERR_DOCKER_COMPOSE_DEPLOY=102
export ERR_DB_SYNC=103
export ERR_CLONE=104
export ERR_ENV=105
export ERR_DOWNLOAD=106


######  Calling Main Function #######
main


