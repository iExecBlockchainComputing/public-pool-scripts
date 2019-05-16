#!/bin/bash

# Variables
WORKER_POOLNAME=public
DEPOSIT=4000000000
CHAIN=mainnet
MINETHEREUM=0.1
HUBCONTRACT=0xb3901d04CF645747b99DBbe8f2eE9cb41A89CeBF
WORKER_DOCKER_IMAGE_VERSION=3.0.0
IEXEC_CORE_HOST=public-pool.iex.ec
IEXEC_CORE_PORT=18090
IEXEC_SDK_VERSION=latest

# Function that prints messages
function message() {
  echo "[$1] $2"
  if [ "$1" == "ERROR" ]; then
    read -p "Press [Enter] to exit..."
    exit 1
  fi
}

# Function which checks exit status and stops execution
function checkExitStatus() {
  if [ $1 -eq 0 ]; then
    message "OK" ""
  else
    message "ERROR" "$2"
  fi
}

# Remove worker function
function removeWorker(){
    message "INFO" "Removing worker."
    docker rm -f "$WORKER_POOLNAME-worker"
}

# Remove worker option
if [ "$1" == "--remove" ]; then
    removeWorker
    checkExitStatus $? "Unable to remove $WORKER_POOLNAME worker."
    message "INFO" "To start a new worker please relaunch the script."
    read -p "Press [Enter] to exit..."
    exit 1
fi

# Update worker option
if [ "$1" == "--update" ]; then
    message "INFO" "Updating worker."
    removeWorker
    message "INFO" "Starting a new worker."
fi

# Determine OS platform
message "INFO" "Detecting OS platform..."
UNAME=$(uname | tr "[:upper:]" "[:lower:]")

# If Linux, try to determine specific distribution
if [ "$UNAME" == "linux" ]; then
  # If available, use LSB to identify distribution
  if [ -f /etc/lsb-release -o -d /etc/lsb-release.d ]; then
      DISTRO=$(lsb_release -i | cut -d: -f2 | sed s/'^\t'//)
  # Otherwise, use release info file
  else
      DISTRO=$(ls -d /etc/[A-Za-z]*[_-][rv]e[lr]* | grep -v "lsb" | cut -d'/' -f3 | cut -d'-' -f1 | cut -d'_' -f1 | head -n 1)
  fi
fi

# For everything else (or if above failed), just use generic identifier
[ "$DISTRO" == "" ] && DISTRO=$UNAME

# Check if OS platform is supported
if [ "$DISTRO" != "Ubuntu" ] && [ "$DISTRO" != "darwin" ] && [ "$DISTRO" != "centos" ]; then
  message "ERROR" "Only Ubuntu OS and MacOS platform is supported for now. Your platform is: $DISTRO"
else
  message "OK" "Detected supported OS platform [$DISTRO] ..."
fi

# Launch iexec sdk function
function iexec {
  if [ "$DISTRO" != "darwin" ]; then
    docker run -e DEBUG=$DEBUG --interactive --tty --rm -v /tmp:/tmp -v $(pwd):/iexec-project -v /home/$(whoami)/.ethereum/keystore:/home/node/.ethereum/keystore -w /iexec-project iexechub/iexec-sdk:$IEXEC_SDK_VERSION "$@"
  else
    docker run -e DEBUG=$DEBUG --interactive --tty --rm -v /tmp:/tmp -v $(pwd):/iexec-project -v /Users/$(whoami)/Library/Ethereum/keystore:/home/node/.ethereum/keystore -w /iexec-project iexechub/iexec-sdk:$IEXEC_SDK_VERSION "$@"
  fi
}

# Check if docker is installed
message "INFO" "Checking if docker is installed..."
which docker >/dev/null 2>/dev/null
if [ $? -eq 0 ]
then
    (docker --version | grep "Docker version")>/dev/null  2>/dev/null
    if [ $? -eq 0 ]
    then
        message "OK" "Docker is installed."
    else
        message "ERROR" "Docker is not installed at your system. Please install it."
    fi
else
    message "ERROR" "Docker is not installed at your system. Please install it."
fi

# Checking connection and changing docker mirror if necessary
message "INFO" "Checking connection [trying to contact google.com] ..."

if ping -c 1 google.com &> /dev/null; then
  message "OK" "Connection is ok."
else
  while [ "$answerdocker" != "yes" ] && [ "$answerdocker" != "no" ]; do
    read -p "Are you from China? [yes/no] " answerdocker
  done

  if [ "$answerdocker" == "yes" ]; then
    message "INFO" "Changing docker mirror..."
    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json <<-'EOF'
{
 "registry-mirrors": ["https://registry.docker-cn.com"]
}
EOF
    sudo systemctl daemon-reload
    sudo systemctl restart docker
  fi
fi

# Checking containers
RUNNINGWORKERS=$(docker ps --format '{{.ID}}' --filter="name=$WORKER_POOLNAME-worker")
STOPPEDWORKERS=$(docker ps --filter "status=exited" --filter "status=created" --filter "status=dead" --format '{{.ID}}' --filter="name=$WORKER_POOLNAME-worker")

# If worker is already running we will just attach to it
if [ ! -z "${RUNNINGWORKERS}" ]; then

    message "INFO" "iExec $WORKER_POOLNAME worker is already running at your machine..."

    # Attach to worker container
    while [ "$attachworker" != "yes" ] && [ "$attachworker" != "no" ]; do
      read -p "Do you want to see logs of your worker? [yes/no] " attachworker
    done

    if [ "$attachworker" == "yes" ]; then
      message "INFO" "Showing logs of worker container."
      docker container logs $(echo $RUNNINGWORKERS)
    fi

elif [ ! -z "${STOPPEDWORKERS}" ]; then

    message "INFO" "Stopped $WORKER_POOLNAME worker detected."

    # Relaunch worker container
    while [ "$relaunchworker" != "yes" ] && [ "$relaunchworker" != "no" ]; do
      read -p "Do you want to relauch stopped worker? [yes/no] " relaunchworker
    done

    if [ "$relaunchworker" == "yes" ]; then
        message "INFO" "Relaunching stopped worker."
        docker start $(echo $STOPPEDWORKERS)
        message "INFO" "Worker was sucessfully started."

        # Attach to worker container
        while [ "$attachworker" != "yes" ] && [ "$attachworker" != "no" ]; do
          read -p "Do you want to see logs of your worker? [yes/no] " attachworker
        done

        if [ "$attachworker" == "yes" ]; then
          message "INFO" "Showing logs of worker container."
          docker container logs $(echo $STOPPEDWORKERS)
        fi
    fi

else

    # Pulling iexec sdk
    message "INFO" "Pulling iexec sdk..."
    docker pull iexechub/iexec-sdk:$IEXEC_SDK_VERSION
    checkExitStatus $? "Failed to pull image. Check docker service state or if user has rights to launch docker commands."

    # Looping over wallet files in inverse order (from the most recent to older one)
    WALLET_SELECTED=0

    if [ "$DISTRO" == "darwin" ]; then
        files=(/Users/$(whoami)/Library/Ethereum/keystore/*)
        mkdir -p /Users/$(whoami)/Library/Ethereum/keystore/
    else
        files=(/home/$(whoami)/.ethereum/keystore/*)
        mkdir -p /home/$(whoami)/.ethereum/keystore/
    fi

    for ((i=${#files[@]}-1; i>=0; i--)); do

        if [ $(cat ${files[$i]}) = "PASTE_YOUR_WALLET_HERE" ]; then
           echo "[INFO] Skipping wallet.json"
           continue
        fi

        # If a wallet was found
        if [[ -f ${files[$i]} ]]; then
            message "INFO" "Found wallet in ${files[$i]}"
            # Extracting wallet address
            WALLET_ADDR=$(cat ${files[$i]} | awk -v RS= '{$1=$1}1' | tr -d "[:space:]" | sed -E "s/.*\"address\":\"([a-zA-Z0-9]+)\".*/\1/g")

            while [ "$answerwalletuse" != "yes" ] && [ "$answerwalletuse" != "no" ]; do
                read -p "Do you want to use wallet 0x$WALLET_ADDR? [yes/no] " answerwalletuse
            done

            # If user selects a wallet
            if [ "$answerwalletuse" == "yes" ]; then

                # Get wallet password and check it with iExec SDK
                read -p "Please provide the password of wallet $WALLET_ADDR: " WORKERWALLETPASSWORD
                WALLET_FILE=${files[$i]}
                WALLET_SELECTED=1

                rm -fr /tmp/iexec
                mkdir /tmp/iexec
                cd /tmp/iexec

                message "INFO" "Initializing SDK."
                iexec init --skip-wallet --force
                checkExitStatus $? "Can't init iexec sdk."

                message "INFO" "Checking wallet password."
                iexec wallet show --wallet-file $(basename $WALLET_FILE) --password "$WORKERWALLETPASSWORD" --chain $CHAIN
                checkExitStatus $? "Invalid wallet password."
                break;
            fi

            unset answerwalletuse
        fi
    done

    # If no wallet was selected
    if [ "$WALLET_SELECTED" == 0 ]; then

        message "INFO" "No wallet was selected."
        while [ "$answerwalletcreate" != "yes" ] && [ "$answerwalletcreate" != "no" ]; do
            read -p "Do you want to create a wallet? [yes/no] " answerwalletcreate
        done

        # If user accepts to create a wallet
        if [ "$answerwalletcreate" == "yes" ]; then

            # Get wallet password
            read -p "Please provide a password to create an encrypted wallet: " WORKERWALLETPASSWORD
            rm -fr /tmp/iexec
            mkdir /tmp/iexec
            cd /tmp/iexec

            message "INFO" "Getting created wallet info."
            IEXEC_INIT_RESULT=$(iexec init --force --raw --password "$WORKERWALLETPASSWORD")
            checkExitStatus $? "Can't create a wallet. Failed init."


            # Get wallet address and wallet file path
            WALLET_ADDR=$(echo $IEXEC_INIT_RESULT | sed -E "s/.*\"walletAddress\":\"([0-9a-zA-Z]+)\".*/\1/g")
            WALLET_FILE=$(echo $IEXEC_INIT_RESULT | sed -E "s/.*\"walletFile\":\"([0-9a-zA-Z\/.-]+)\".*/\1/g")
            # Replacing node home with current user home
            if [ "$DISTRO" == "darwin" ]; then
                WALLET_FILE=$(echo $WALLET_FILE | sed "s/home\/node\/\.ethereum/Users\/$(whoami)\/Library\/Ethereum/g")
            else
                WALLET_FILE=$(echo $WALLET_FILE | sed "s/node/$(whoami)/g")
            fi

            message "INFO" "A wallet with address $WALLET_ADDR was created in $WALLET_FILE."

            message "INFO" "Please fill your wallet with minimum $MINETHEREUM ETH and $DEPOSIT nRLC. Then relaunch the script."
            read -p "Press [Enter] to exit..."
            exit 1

        else
            message "INFO" "You cannot launch a worker without a wallet. Exiting..."
            read -p "Press [Enter] to exit..."
            exit 1
        fi
    fi

    echo "WALLET FILE: $WALLET_FILE"

    message "INFO" "The wallet $WALLET_ADDR with password $WORKERWALLETPASSWORD and path $WALLET_FILE will be used..."

    message "INFO" "Checking wallet balances."

    message "INFO" "Init iExec SDK."
    iexec init --force --skip-wallet
    checkExitStatus $? "Can't init iexec sdk."

    message "INFO" "Adding Hub Contract address."
    sed -i'.temp' -E "s/(\"id\": \"42\")/\1\,\ \"hub\":\"$HUBCONTRACT\"/g" chain.json

    checkExitStatus $? "Can't place hub address."

    message "INFO" "Getting wallet info."
    WALLETINFO=$(iexec wallet show --raw --wallet-file $(basename $WALLET_FILE) --password "$WORKERWALLETPASSWORD" --chain $CHAIN)
    checkExitStatus $? "Can't get wallet info."

    message "INFO" "Getting account info."
    ACCOUNTINFO=$(iexec account show --raw --wallet-file $(basename $WALLET_FILE) --password "$WORKERWALLETPASSWORD" --chain $CHAIN)
    checkExitStatus $? "Can't get account info."

    # Getting necessary values
    ETHEREUM=$(echo $WALLETINFO | sed -E "s/.*\"ETH\":\"([0-9.]+)\".*/\1/g")
    NRLC=$(echo $WALLETINFO | sed -E "s/.*\"nRLC\":\"([0-9.]+)\".*/\1/g")
    STAKE=$(echo $ACCOUNTINFO | sed -E "s/.*\"stake\":\"([0-9.]+)\".*/\1/g")

    # Showing balances
    message "INFO" "Ethereum balance is $ETHEREUM ETH."
    message "INFO" "Stake amount is $STAKE nRLC."

    # Checking minimum ethereum
    if [ $(echo $ETHEREUM'<'$MINETHEREUM | bc -l) -ne 0 ]; then
      message "ERROR" "You need to have $MINETHEREUM ETH to launch iExec worker. Your balance is $ETHEREUM ETH."
    fi

    # Calculate amount to deposit
    TODEPOSIT=$(($DEPOSIT - $STAKE))

    # Checking if wallet has enough nRLC to deposit
    if [ $NRLC -lt $TODEPOSIT ]; then
      message "ERROR" "You need to have $TODEPOSIT nRLC to make a deposit. But you have only $NRLC nRLC."
    fi

    # Checking deposit
    if [ $STAKE -lt $DEPOSIT ]; then

      # Ask for deposit agreement
      while [ "$answer" != "yes" ] && [ "$answer" != "no" ]; do
        read -p "To participate you need to deposit $TODEPOSIT nRLC. Do you agree? [yes/no] " answer
      done

      if [ "$answer" == "no" ]; then
        message "ERROR" "You can't participate without deposit."
      fi

      # Deposit
      iexec account deposit $TODEPOSIT --wallet-file $(basename $WALLET_FILE) --password "$WORKERWALLETPASSWORD" --chain $CHAIN
      checkExitStatus $? "Failed to depoit."
    else
      message "OK" "You don't need to stake. Your stake is $STAKE."
    fi

    # Get worker name
    while [[ ! "$WORKER_NAME" =~ ^[-_A-Za-z0-9]+$ ]]; do
      read -p "Enter worker name [only letters, numbers, - and _ symbols]: " WORKER_NAME
    done

    # Get last version and run worker
    message "INFO" "Creating iExec $WORKER_POOLNAME worker..."
    docker pull iexechub/iexec-worker:$WORKER_DOCKER_IMAGE_VERSION
    checkExitStatus $? "Can't pull docker image."
    docker create --name "$WORKER_POOLNAME-worker" \
             --hostname "$WORKER_NAME" \
             --env "IEXEC_CORE_HOST=$IEXEC_CORE_HOST" \
             --env "IEXEC_CORE_PORT=$IEXEC_CORE_PORT" \
             --env "IEXEC_WORKER_NAME=$WORKER_NAME" \
             --env "IEXEC_WORKER_WALLET_PATH=/iexec-wallet/encrypted-wallet.json" \
             --env "IEXEC_WORKER_WALLET_PASSWORD=$WORKERWALLETPASSWORD" \
             -v $WALLET_FILE:/iexec-wallet/encrypted-wallet.json \
             -v /tmp/iexec-worker/${WORKER_NAME}:/tmp/iexec-worker/${WORKER_NAME} \
             -v /var/run/docker.sock:/var/run/docker.sock \
             iexechub/iexec-worker:$WORKER_DOCKER_IMAGE_VERSION
    checkExitStatus $? "Can't start docker container."

    message "INFO" "Created worker $WORKER_POOLNAME-worker."

    # Attach to worker container
    while [ "$startworker" != "yes" ] && [ "$startworker" != "no" ]; do
      read -p "Do you want to start worker? [yes/no] " startworker
    done

    if [ "$startworker" == "yes" ]; then
      message "INFO" "Starting worker."
      docker start $WORKER_POOLNAME-worker
      message "INFO" "Worker was successfully started."
    else
      message "INFO" "You can start the worker later with \"docker start $WORKER_POOLNAME-worker\"."
    fi

fi

read -p "Press [Enter] to exit..."
