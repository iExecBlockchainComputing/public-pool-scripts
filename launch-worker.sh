#!/bin/bash

DEPOSIT=0
CHAIN=mainnet
MINETHEREUM=0.1

function checkExitStatus() {
  if [ $1 -eq 0 ]; then
    echo OK
  else
    echo $2
    read -p "Press [Enter] to exit..."
    exit 1
  fi
}

shopt -s expand_aliases
alias iexec='docker run -e DEBUG=$DEBUG --interactive --tty --rm -v $(pwd):/iexec-project -w /iexec-project iexechub/iexec-sdk'

echo "Welcome to iExec worker"
echo "Checking files..."

RUNNINGWORKERS=$(docker ps --format '{{.Image}} {{.ID}}')
STOPPEDWORKERS=$(docker ps --filter "status=exited" --format '{{.Image}} {{.ID}}')

if [ ! -f /home/iexec/Desktop/iExec/encrypted-wallet.json ] || [ $(cat /home/iexec/Desktop/iExec/encrypted-wallet.json | wc -c) -eq 0 ]; then
      echo "Wallet not found or empty! (iExec/encrypted-wallet.json)"
      echo "Please check your wallet in iExec directory."
      read -p "Press [Enter] to exit..."
      exit 1
fi

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
    while [[ ! $workerName =~ ^[-_A-Za-z0-9]+$ ]]; do
      read -p "Enter worker name [only letters, numbers, - and _ symbols]: " workerName
    done

    read -p "Enter wallet password: " password

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

    ETHEREUM=$(iexec wallet show --chain $CHAIN | grep ETH | awk '{print $3}' | sed 's/[^0-9.]*//g')
    STAKE=$(iexec account show --chain $CHAIN | grep stake | awk '{print $3}' | sed 's/[^0-9]*//g')

    if [ $(echo $ETHEREUM'<'$MINETHEREUM | bc -l) -ne 0 ]; then
      echo "You need to have $MINETHEREUM ETH to launch iExec worker. But you only have $ETHEREUM ETH."
      read -p "Press [Enter] to exit..."
      exit 1
    fi

    if [ $STAKE -lt $DEPOSIT ]; then
      TODEPOSIT=$(($DEPOSIT - $STAKE))
      while [ "$answer" != "yes" ] && [ "$answer" != "no" ]; do
        read -p "To participate you need to deposit $TODEPOSIT nRLC. Do you agree? [yes/no] " answer
      done

      if [ "$answer" == "no" ]; then
        read -p "Press [Enter] to exit..."
        exit 1
      fi

      iexec account deposit $TODEPOSIT --chain $CHAIN
      checkExitStatus $? "Failed to depoit."
    else
      echo "You don't need to stake. Your stake is $STAKE."
    fi

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
