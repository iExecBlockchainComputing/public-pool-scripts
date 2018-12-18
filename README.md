# workerdrop-scripts-public

# I see transactions who is who? with the first 8 digit you can guess :

0x0c6e29e3 => subscribetopool

0x7c609885 => allowworkersToConteribute

0x031ee1c8 => contribute 

0x16ebf77d => revealConsensus

0x5a628525 => reveal

0x06021e7e => finalized

More details of thoses functions here :
https://medium.com/iex-ec/poco-series-3-poco-protocole-update-a2c8f8f30126

# How to see my worker balances :
## Option A :  with VM and iexec-sdk ?

- In the VM desktop, enter the folder iExec
- Right click. "Open in Teminal"
- To see your RLC balance 
```
iexec wallet show --chain mainnet
```
- To see RLC deposit balance and rewards 
```
iexec account show --chain mainnet
```

You will notice 2 differents lines for the account balance. ‘Stake’ and ‘Locked’.

Stake balance can be withdrawn from marketplace and received as ERC20 RLC as you know it. This ‘Stake’ balance can be used either to stake or to pay for executions and is the balance increased when you make a deposit.

When workers place their stake to execute a task, ‘Stake’ balance decreases and ‘Locked’ balance increases accordingly.

These funds are locked until the work order is complete. When the work order is completed (and PoCo consensus is achieved), ‘Locked ’balance of the user is seized and the stake balance of contributors (workers) is increased, according to smart contract rewards distributions rules.

## Option B :How to see my worker balances with etherscan ?
 To see your RLC balance . As usual in etherescan 

To see RLC deposit balance and rewards :
https://etherscan.io/address/0x0d5ef019ca4c5cc413ee892ced89d7107c5f424d#readContract

scroll down to :
7. checkBalance

- Put your worker address in _owner (address)

and click : Query

## Option C: How to see my worker balances with iExec Account interface ?

Instructions TODO


# How to withdraw my rewards ? 

Just click on "Stop worker" Icon in the desktop VM. It will ask you to withdraw if you have any rewards or balances. See iexec-sdk withdraw code used [here](https://github.com/iExecBlockchainComputing/workerdrop-scripts-public/blob/master/stop-worker.sh#L33) 



# How to see my worker score with etherscan ?

go :
https://etherscan.io/address/0x0d5ef019ca4c5cc413ee892ced89d7107c5f424d#readContract

scroll down to :
7. m_scores

- Put your worker address in _owner (address)

and click : Query

# rewards distribution according to score : 
https://github.com/iExecBlockchainComputing/PoCo/blob/master/contracts/WorkerPool.sol#L416
