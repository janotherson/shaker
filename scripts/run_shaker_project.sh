#!/bin/sh                                                                                                                                                                       

# global vars
SCENARIO=${1:-openstack/custom/fip_to_fip_dense}
SERVER_IP=${2:-10.26.36.217}
PORT=${3:-20000}
PATH_TEST=${4:-load_test}
PROJECT_NAME=$(echo "shaker_$PORT")
PROVIDER=${5:-provider1}
log=$(echo "logs/$PROJECT_NAME.log")
PROJ_ID=""
ZONE=${6:-shaker-1a,shaker-1b,shaker-1c}
EXTRA_FLAGS=${7}
OPENSTACK_USER="admin"

create_project ()
{
  echo "creating project" >> $log

  project=$(openstack project create \
	--domain jaxyendy \
	--description "Test Project" $PROJECT_NAME \
	| egrep ' name | id ' | awk '{print $4}' | xargs)
  PROJ_ID=$(echo $project | awk '{print $1}')
  proj_name=$(echo $project | awk '{print $2}')
  echo "project_name: $proj_name, project_id: $PROJ_ID" >> $log

  openstack role add --user $OPENSTACK_USER --project $proj_name admin

}

remove_project ()
{
  echo "removing project" >> $log

  openstack server list -f value -c ID --project $PROJ_ID | while read instance
  do
    openstack server show $instance
    openstack server delete --os-project-id $PROJ_ID $instance
  done

  openstack floating ip list -f value -c ID --project $PROJ_ID | while read float
  do
    openstack float ip show $float
    openstack floating ip delete --os-project-id $PROJ_ID $float
  done

  openstack router list -f value -c ID --project $PROJ_ID | while read router
  do
    openstack router show $router
    subnet=$(openstack router show --os-project-id $PROJ_ID $router | grep interfaces_info| cut -d'"' -f 12)
    openstack router remove subnet --os-project-id $PROJ_ID $router $subnet
    openstack router delete --os-project-id $PROJ_ID $router
  done

  openstack port list --long -f value -c ID -c 'Device Owner' --project $PROJ_ID | grep -v network:dhcp | while read port
  do
    openstack port show $port
    port_id=$(echo $port | awk '{print $1}')
    neutron port-update --device-owner clear $port_id
    openstack port delete $port_id
  done

  openstack network list -f value -c ID --project $PROJ_ID | while read network
  do
    openstack network show $network
    openstack network delete --os-project-id $PROJ_ID $network
  done

  openstack security group list -f value -c ID --project $PROJ_ID | while read sg
  do
    openstack security group show $sg
    openstack security group delete --os-project-id $PROJ_ID $sg
  done

  openstack project purge --project $PROJ_ID

}

mkdir -p logs
# run shaker test
echo "Start Test!" >> $log

create_project

shaker $EXTRA_FLAGS --scenario-availability-zone $ZONE --os-project-name $PROJECT_NAME --external-net $PROVIDER --image-name shaker-image-metadata  --agent-loss-timeout 600 --agent-join-timeout 600 --agent-dir=/tmp --server-endpoint $SERVER_IP:$PORT --scenario\
 $SCENARIO --report /var/www/html/shaker/$PATH_TEST/$PROJECT_NAME.dense_test.html >> $log 2>> $.log

remove_project

echo "done!" >> $log
