#!/bin/bash

# Config
DEPOSIT=0
CHAIN=mainnet
MINETHEREUM=0.2

# Function which checks exit status and stops execution
function checkExitStatus() {
  if [ $1 -eq 0 ]; then
    echo OK
  else
    echo $2
    read -p "Press [Enter] to exit..."
    exit 1
  fi
}

# Checking connection and changing docker mirror if necessary
echo "Checking connection..."
if ping -c 1 google.com &> /dev/null; then
  echo "Connection is ok."
else
  while [ "$answerdocker" != "yes" ] && [ "$answerdocker" != "no" ]; do
    read -p "Are you from China? [yes/no] " answerdocker
  done

  if [ "$answerdocker" == "yes" ]; then
    echo "Changing docker mirror..."
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

# Creating iexec alias
shopt -s expand_aliases
alias iexec='docker run -e DEBUG=$DEBUG --interactive --tty --rm -v $(pwd):/iexec-project -w /iexec-project iexechub/iexec-sdk'

echo "Welcome to iExec worker"
echo "Checking files..."

# Pulling iexec sdk
docker pull iexechub/iexec-sdk

# Checking containers
RUNNINGWORKERS=$(docker ps --format '{{.Image}} {{.ID}}')
STOPPEDWORKERS=$(docker ps --filter "status=exited" --format '{{.Image}} {{.ID}}')

# Checking wallet file
if [ ! -f /home/iexec/Desktop/iExec/encrypted-wallet.json ] || [ $(cat /home/iexec/Desktop/iExec/encrypted-wallet.json | wc -c) -eq 0 ]; then
      echo "Wallet not found or empty! (iExec/encrypted-wallet.json)"
      echo "Please check your wallet in iExec directory."
      read -p "Press [Enter] to exit..."
      exit 1
fi

# If container was stopped relaunching it and attaching to container
if [ ! -z "${STOPPEDWORKERS}" ]; then
  echo "Stopped worker detected."
  echo "Launching stopped worker."
  docker start $(echo $STOPPEDWORKERS | awk '{print $2}')
  docker container attach $(echo $STOPPEDWORKERS | awk '{print $2}')
else
  if [ ! -z "${RUNNINGWORKERS}" ]; then
    echo "iExec worker is already running at your machine..."
    echo "Attaching to running container"
    docker container attach $(echo $RUNNINGWORKERS | awk '{print $2}')
  else
    # Get worker name
    while [[ ! $workerName =~ ^[-_A-Za-z0-9]+$ ]]; do
      read -p "Enter worker name [only letters, numbers, - and _ symbols]: " workerName
    done

    # Get wallet password
    read -p "Enter wallet password: " password

    # iexec init sdk environment
    cd /home/iexec/Desktop/iExec;
    rm -f chain.json wallet.json
    iexec init
    checkExitStatus $? "Failed to execute iexec init"
    rm -f iexec.json account.json wallet.json

    iexec wallet decrypt --password $password
    checkExitStatus $? "Unable to decrypt wallet."

    iexec account login --chain $CHAIN
    checkExitStatus $? "Failed to login."

    iexec wallet show --chain $CHAIN

    # Get wallet and account info
    ETHEREUM=$(iexec wallet show --chain $CHAIN | grep ETH | awk '{print $3}' | sed 's/[^0-9.]*//g')
    STAKE=$(iexec account show --chain $CHAIN | grep stake | awk '{print $3}' | sed 's/[^0-9]*//g')

    # Checking minimum ethereum
    if [ $(echo $ETHEREUM'<'$MINETHEREUM | bc -l) -ne 0 ]; then
      echo "You need to have $MINETHEREUM ETH to launch iExec worker. But you only have $ETHEREUM ETH."
      read -p "Press [Enter] to exit..."
      exit 1
    fi

    # Checking deposit
    if [ $STAKE -lt $DEPOSIT ]; then
      TODEPOSIT=$(($DEPOSIT - $STAKE))

      # Ask for deposit agreement
      while [ "$answer" != "yes" ] && [ "$answer" != "no" ]; do
        read -p "To participate you need to deposit $TODEPOSIT nRLC. Do you agree? [yes/no] " answer
      done

      if [ "$answer" == "no" ]; then
        read -p "Press [Enter] to exit..."
        exit 1
      fi

      # Deposit
      iexec account deposit $TODEPOSIT --chain $CHAIN
      checkExitStatus $? "Failed to depoit."
    else
      echo "You don't need to stake. Your stake is $STAKE."
    fi

    # Get last version and run worker
    echo "Starting iExec worker..."
    docker pull iexechub/worker:latest
    docker run --hostname $workerName \
             --env SCHEDULER_DOMAIN=api-workerdrop-pool.iex.ec \
             --env SCHEDULER_IP=52.52.233.12 \
             --env LOGIN=worker \
             --env PASSWORD=K2ovTKF6mfHbDx5kDsyi \
             --env LOGGERLEVEL=INFO \
             --env SHAREDPACKAGES= \
             --env SANDBOXENABLED=true \
             --env BLOCKCHAINETHENABLED=true \
             --env SHAREDAPPS=docker \
             --env TMPDIR=/tmp/iexec-worker-drop \
             --env WALLETPASSWORD=$password \
             -v /home/iexec/Desktop/iExec/encrypted-wallet.json:/iexec/wallet/wallet_worker.json \
             -v /var/run/docker.sock:/var/run/docker.sock \
             -v /tmp/iexec-worker-drop:/tmp/iexec-worker-drop \
             iexechub/worker:latest
  fi
fi

read -p "Press [Enter] to exit..."
