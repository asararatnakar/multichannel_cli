#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#


#UP_DOWN="$1"
CHANNELS="$1"
CCS="$2"
IF_COUCHDB="$3"
: ${TIMEOUT:="10000"}
: ${UP_DOWN:="restart"}
: ${CHANNELS:="1"}
: ${CCS:="1"}
export CHANNELS
export CCS
export TIMEOUT
COMPOSE_FILE=docker-compose-cli.yaml
COMPOSE_FILE_COUCH=docker-compose-couch.yaml

function printHelp () {
	echo "Usage: ./network_setup <up|down> <total_channels> <total_chaincodes>  <couchdb>.\nThe arguments must be in order."
}

function clearContainers () {
        CONTAINER_IDS=$(docker ps -aq)
        if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" = " " ]; then
                echo "---- No containers available for deletion ----"
        else
                docker rm -f $CONTAINER_IDS
        fi
}

function removeUnwantedImages() {
        DOCKER_IMAGE_IDS=$(docker images | grep "dev\|none\|test-vp\|peer[0-9]-" | awk '{print $3}')
        if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" = " " ]; then
                echo "---- No images available for deletion ----"
        else
                docker rmi -f $DOCKER_IMAGE_IDS
        fi
}

function networkUp () {
    #Generate all the artifacts that includes org certs, orderer genesis block,
    # channel configuration transaction
    #source generateArtifacts.sh
    if [ "${IF_COUCHDB}" == "couchdb" ]; then
      docker-compose -f $COMPOSE_FILE -f $COMPOSE_FILE_COUCH up -d 2>&1
    else
      docker-compose -f $COMPOSE_FILE up -d 2>&1
    fi
    if [ $? -ne 0 ]; then
	echo "ERROR !!!! Unable to pull the images "
	exit 1
    fi
    docker logs -f cli
}

function networkDown () {
    docker-compose -f $COMPOSE_FILE down

    #Cleanup the chaincode containers
    clearContainers

    #Cleanup images
    removeUnwantedImages

    # remove orderer block and other channel configuration transactions and certs
    #rm -rf channel-artifacts/*.block channel-artifacts/*.tx crypto-config
}

function init() {
	IMAGE_TAG="x86_64-1.0.0-rc1"
	DOCKER_IMAGES=$(docker images | grep "$IMAGE_TAG" | wc -l)
	if [ $DOCKER_IMAGES -lt 9 ]; then
		printf "\n############# You don't have all fabric images, Let me them pull for you ###########\n"
		for IMAGE in peer orderer ca couchdb ccenv javaenv kafka tools zookeeper; do
		      docker pull hyperledger/fabric-$IMAGE:$IMAGE_TAG
		      docker tag hyperledger/fabric-$IMAGE:$IMAGE_TAG hyperledger/fabric-$IMAGE:latest
		done
	fi	
}
init
#Create the network using docker compose
if [ "${UP_DOWN}" == "up" ]; then
	networkUp
elif [ "${UP_DOWN}" == "down" ]; then ## Clear the network
	networkDown
elif [ "${UP_DOWN}" == "restart" ]; then ## Restart the network
	networkDown
	networkUp
else
	printHelp
	exit 1
fi
