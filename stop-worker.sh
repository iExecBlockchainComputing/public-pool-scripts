#!/bin/bash

# Config
CHAIN=mainnet

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

# Creating iexec alias
shopt -s expand_aliases
alias iexec='docker run -e DEBUG=$DEBUG --interactive --tty --rm -v $(pwd):/iexec-project -w /iexec-project iexechub/iexec-sdk'

echo "Stopping iExec Worker..."

# Make a withdraw
cd /home/iexec/Desktop/iExec

STAKE=$(iexec account show --chain $CHAIN | grep stake | awk '{print $3}' | sed 's/[^0-9]*//g')

if [ ! -z $STAKE ] && [ $STAKE -ne 0 ]; then
  while [ "$answer" != "yes" ] && [ "$answer" != "later" ]; do
    read -p "You have $STAKE nRLC. Would you like to withdraw them? [yes/later] " answer
  done
  if [ "$answer" == "yes" ]; then
    iexec account withdraw $STAKE --chain $CHAIN
  fi
fi

# Stop and delete container
RUNNINGWORKERS=$(docker ps -a --format '{{.Image}} {{.ID}} ')

if [ ! -z "${RUNNINGWORKERS}" ]; then
  RUNNING_WORKER_ID=$(echo $RUNNINGWORKERS | awk '{print $2}')
  docker stop $RUNNING_WORKER_ID
  docker rm $RUNNING_WORKER_ID
  echo "iExec worker was successfully stopped."
else
  echo "iExec worker is not launched."
fi

read -p "Press [Enter] to exit..."
