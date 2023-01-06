#!/bin/sh                                                                                                                                                                       

# global vars
SCENARIO=${1:-openstack/custom/l2_ipv4}
SERVER_IP=${2:-192.168.1.1}
PORT_BASE=${3:-20000}
PORT=$PORT_BASE
STEPS=${4:-1}
SLEEP_TIME=${5:-600}
PATH_TEST=${6:-load_test}
PROVIDER=${7:-provider1}
ZONE=$8
EXTRA_FLAGS=$9

RELATIVE_DIR="${0%/*}"
SCRIPT_PATH=$RELATIVE_DIR

for lote in `seq 1 $STEPS`;do
  $SCRIPT_PATH/run_shaker_project.sh $SCENARIO $SERVER_IP $PORT $PATH_TEST $PROVIDER $ZONE $EXTRA_FLAGS &
  PORT=$(($PORT_BASE + $lote))

  sleep $SLEEP_TIME
done
