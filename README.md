# MultiChannels and MultiChaincodes (For Scalability tests)

This is similar to `e2e_cli` available in fabic. Made changes to the script to send transactions on multiple 
channels and chaincodes (onto a single peer)

**Usage:**

```

./network_setup.sh <# of channels> <# of chaincodes> <enable/disable couchdb>

```
ex:

```
./network_setup.sh 4 8 couchdb

./network_setup.sh 100 10

```

First one, 4 Channel, 8 Chaincodes and enable CouchDB
Second one, 100 Channel, 10 Chaincodes

** When no arguments supplied, `./network_setup.sh` defaults to 1 channel and 1 chaincode.

**NOTE**: 
* This uses **RC1** based images and binaries
* Artifacts are generated only for **100** Channels

