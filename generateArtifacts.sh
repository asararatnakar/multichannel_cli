#!/bin/bash +x

set -e

CHANNEL_NAME=$1
: ${CHANNEL_NAME:="mychannel"}
: ${TOTAL_CHANNELS:=100}
export FABRIC_ROOT=$PWD/../..
export FABRIC_CFG_PATH=$PWD
echo


## Generates Org certs using cryptogen tool
function generateCerts (){
	CRYPTOGEN=$PWD/bin/cryptogen
	$CRYPTOGEN generate --config=./crypto-config.yaml
	echo
}

## Generate orderer genesis block , channel configuration transaction and anchor peer update transactions
function generateChannelArtifacts() {

	CONFIGTXGEN=$PWD/bin/configtxgen

	$CONFIGTXGEN -profile TwoOrgsOrdererGenesis -outputBlock ./channel-artifacts/genesis.block

	for (( i=1;i<=$TOTAL_CHANNELS;i=$i+1 ))
	do
		$CONFIGTXGEN -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/channel$i.tx -channelID $CHANNEL_NAME$i

		$CONFIGTXGEN -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org1MSPanchors$i.tx -channelID $CHANNEL_NAME$i -asOrg Org1MSP

		$CONFIGTXGEN -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org2MSPanchors$i.tx -channelID $CHANNEL_NAME$i -asOrg Org2MSP
		echo
	done
}

generateCerts

generateChannelArtifacts

