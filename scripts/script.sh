#!/bin/bash
# Copyright London Stock Exchange Group All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
set +x
#set -ev
echo " ____    _____      _      ____    _____           _____   ____    _____ "
echo "/ ___|  |_   _|    / \    |  _ \  |_   _|         | ____| |___ \  | ____|"
echo "\___ \    | |     / _ \   | |_) |   | |    _____  |  _|     __) | |  _|  "
echo " ___) |   | |    / ___ \  |  _ <    | |   |_____| | |___   / __/  | |___ "
echo "|____/    |_|   /_/   \_\ |_| \_\   |_|           |_____| |_____| |_____|"

exectime=$(date +%s)
TOTAL_CHANNELS=$1
TOTAL_CCS=$2
: ${TOTAL_CHANNELS:=1}
: ${TOTAL_CCS:=1}
LOG_LEVEL="error"
CHANNEL_NAME="mychannel"
: ${TIMEOUT:="60"}
COUNTER=1
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

printf "Channel name : "$CHANNEL_NAME

verifyResult () {
	if [ $1 -ne 0 ] ; then
		printf "\n!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!\n"
                printf "\n================== ERROR !!! FAILED to execute End-2-End Scenario ==================\n"
		printf "\nTotal execution time : $(($(date +%s) - exectime)) secs ...\n\n"
   		exit 1
	fi
}
function wait() {
	printf "\nWait for $1 secs\n"
	sleep $1
}
setGlobals () {

	if [ $1 -eq 0 -o $1 -eq 1 ] ; then
		CORE_PEER_LOCALMSPID="Org1MSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
		if [ $1 -eq 0 ]; then
			CORE_PEER_ADDRESS=peer0.org1.example.com:7051
		else
			CORE_PEER_ADDRESS=peer1.org1.example.com:7051
			CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
		fi
	else
		CORE_PEER_LOCALMSPID="Org2MSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
		if [ $1 -eq 2 ]; then
			CORE_PEER_ADDRESS=peer0.org2.example.com:7051
		else
			CORE_PEER_ADDRESS=peer1.org2.example.com:7051
		fi
	fi

	#env |grep CORE
}

createChannel() {
	setGlobals 0

        if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel create -o orderer.example.com:7050 -c $CHANNEL_NAME$1 -f ./channel-artifacts/channel$1.tx --logging-level=$LOG_LEVEL >&log.txt
	else
		peer channel create -o orderer.example.com:7050 -c $CHANNEL_NAME$1 -f ./channel-artifacts/channel$1.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA --logging-level=$LOG_LEVEL >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Channel creation failed"
	printf "\n===================== Channel \"$CHANNEL_NAME$1\" is created successfully ===================== \n"
}

updateAnchorPeers() {
        PEER=$1
        setGlobals $PEER

        if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel update -o orderer.example.com:7050 -c $CHANNEL_NAME$2 -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors$2.tx --logging-level=$LOG_LEVEL >&log.txt
	else
		peer channel update -o orderer.example.com:7050 -c $CHANNEL_NAME$2 -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors$2.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA --logging-level=$LOG_LEVEL >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Anchor peer update failed"
	printf "\n===================== Anchor peers for org \"$CORE_PEER_LOCALMSPID\" on \"$CHANNEL_NAME$2\" is updated successfully ===================== \n"
}

## Sometimes Join takes time hence RETRY atleast for 5 times
joinWithRetry () {
	peer channel join -b $CHANNEL_NAME$2.block --logging-level=$LOG_LEVEL >&log.txt
	res=$?
	cat log.txt
	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		printf "\nPEER$1 failed to join the channel, Retry after 2 seconds\n"
		wait 2
		joinWithRetry $1 $2
	else
		COUNTER=1
	fi
        verifyResult $res "After $MAX_RETRY attempts, PEER$ch has failed to Join the Channel"
}

joinChannel () {
	for ch in 0 1 2 3; do
		setGlobals $ch
		joinWithRetry $ch $1
		printf "\n===================== PEER$ch joined on the channel \"$CHANNEL_NAME$1\" ===================== \n"
	done
}

installChaincode () {
	PEER=$1
	setGlobals $PEER
	peer chaincode install -n mycc$2 -v 0 -p github.com/hyperledger/fabric/chaincode --logging-level=$LOG_LEVEL >&log.txt
	res=$?
	cat log.txt
        verifyResult $res "Chaincode mycc$2 installation on remote peer PEER$PEER has Failed"
	printf "\n===================== Chaincode mycc$2 is installed on remote peer PEER$PEER ===================== \n"
}

instantiateChaincode () {
	PEER=$1
	setGlobals $PEER
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode instantiate -o orderer.example.com:7050 -C $CHANNEL_NAME$2 -n mycc$3 -v 0 -c '{"Args":[""]}' -P "OR ('Org1MSP.member','Org2MSP.member')" --logging-level=$LOG_LEVEL >&log.txt
	else
		peer chaincode instantiate -o orderer.example.com:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME$2 -n mycc$3 -v 0 -c '{"Args":[""]}' -P "OR ('Org1MSP.member','Org2MSP.member')" --logging-level=$LOG_LEVEL >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Chaincode mycc$3 instantiation on PEER$PEER on channel '$CHANNEL_NAME$2' failed"
	printf "\n===================== Chaincode mycc$3 Instantiation on PEER$PEER on channel '$CHANNEL_NAME$2' is successful ===================== \n"
}
COUNTER1=0
COUNTER2=0
RANDOM_STRING=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
chaincodeQuery () {
  PEER=$1
  COUNTER2=` expr $COUNTER2 + 1 `
  printf "\n===================== Querying on PEER$PEER on channel '$CHANNEL_NAME$2'... ===================== \n"
  setGlobals $PEER
  local rc=1
  local starttime=$(date +%s)

  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
  do
     wait 1
     printf "\nAttempting to Query PEER$PEER ...$(($(date +%s)-starttime)) secs\n"
     peer chaincode query -C $CHANNEL_NAME$2 -n mycc$3 -c "{\"function\":\"get\",\"Args\":[\"$COUNTER2\"]}" --logging-level=$LOG_LEVEL >&log.txt
     test $? -eq 0 && VALUE=$(cat log.txt | awk '/Query Result/ {print $NF}')
     test "$VALUE" = "$RANDOM_STRING" && let rc=0
  done
  cat log.txt
  if test $rc -eq 0 ; then
	printf "\n===================== Query on PEER$PEER on channel '$CHANNEL_NAME$2/mycc$3' is successful ===================== \n"
  else
	printf "\n!!!!!!!!!!!!!!! Query result on PEER$PEER on channel '$CHANNEL_NAME$2/mycc$3' is INVALID !!!!!!!!!!!!!!!!\n"
        printf "\n================== ERROR !!! FAILED to execute End-2-End Scenario ==================\n"
	printf "\nTotal execution time : $(($(date +%s) - exectime)) secs ...\n\n"
	exit 1
  fi
}

chaincodeInvoke () {
	COUNTER1=` expr $COUNTER1 + 1 `
	PEER=$1
	setGlobals $PEER
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode invoke -o orderer.example.com:7050 -C $CHANNEL_NAME$2 -n mycc$3 -c '{"Args":["invoke","a","b","10"]}' --logging-level=$LOG_LEVEL >&log.txt
	else
		peer chaincode invoke -o orderer.example.com:7050  --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME$2 -n mycc$3 -c "{\"function\":\"put\",\"Args\":[\"$COUNTER1\",\"$RANDOM_STRING\"]}" --logging-level=$LOG_LEVEL >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Invoke execution on PEER$PEER failed "
	printf "\n===================== Invoke transaction on PEER$PEER on channel '$CHANNEL_NAME$2/mycc$3' is successful ===================== \n"
}


for (( i=0; i<=3; i=$i+1 ))
do
	for (( j=1; j<=$TOTAL_CCS; j=$j+1 ))
	do
		## Install chaincode mycc$i on peer$i
		printf "\nInstalling chaincode 'mycc$j' on peer$i...\n"
		installChaincode $i $j
	done
done

for (( i=1; i<=$TOTAL_CHANNELS; i=$i+1 ))
do
	## Create channel
	printf "\n\n################# Creating channel $CHANNEL_NAME$i ###############\n\n"
	createChannel $i

	## Join all the peers to the channel
	printf "\nHaving all peers join the channel $CHANNEL_NAME$i...\n"
	joinChannel $i

	## Set the anchor peers for each org in the channel
	printf "\nUpdating anchor peers for org1 on channel $CHANNEL_NAME$i...\n"
	updateAnchorPeers 0 $i
	printf "\nUpdating anchor peers for org2 on channel $CHANNEL_NAME$i...\n"
	updateAnchorPeers 2 $i
	for (( j=1; j<=$TOTAL_CCS; j=$j+1 ))
	do
		#Instantiate chaincode on Peer2/Org2
		printf "\nInstantiating chaincode on org2/peer2...\n"
		instantiateChaincode 2 $i $j
	done
done
wait 30
for (( i=1; i<=$TOTAL_CHANNELS; i=$i+1 ))
do
	for (( j=1; j<=$TOTAL_CCS; j=$j+1 ))
	do
		#Invoke on chaincode on Peer0/Org1
		printf "\nSending invoke transaction on org1/peer0 on mychannel$i/mycc$j...\n"
		chaincodeInvoke 0 $i $j
	done
done
wait 30
for (( i=1; i<=$TOTAL_CHANNELS; i=$i+1 ))
do
	for (( j=1; j<=$TOTAL_CCS; j=$j+1 ))
	do
		#Query chaincode on each peer and validate the result
		printf "\nQuerying chaincode on org1/peer0 on mychannel$i/mycc$j...\n"
		chaincodeQuery 0 $i $j
	done
done
printf "\n\n===================== All GOOD, End-2-End execution completed ===================== \n\n"

echo " _____   _   _   ____            _____   ____    _____ "
echo "| ____| | \ | | |  _ \          | ____| |___ \  | ____|"
echo "|  _|   |  \| | | | | |  _____  |  _|     __) | |  _|  "
echo "| |___  | |\  | | |_| | |_____| | |___   / __/  | |___ "
echo "|_____| |_| \_| |____/          |_____| |_____| |_____|"

printf "\n\nTotal execution time : $(($(date +%s) - exectime)) secs ...\n\n"
