#!/bin/bash
CHAIN=mainnet

shopt -s expand_aliases
alias iexec='docker run -e DEBUG=$DEBUG --interactive --tty --rm -v $(pwd):/iexec-project -w /iexec-project iexechub/iexec-sdk'

echo "Stopping iExec Worker..."

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
