#!/bin/bash

set -x

IP=$(ip route show |grep -o src.* |cut -f2 -d" ")
# kubernetes sets routes differently -- so we will discover our IP differently
if [[ ${IP} == "" ]]; then
  IP=$(hostname -i)
fi
SUBNET=$(echo ${IP} | cut -f1 -d.)
NETWORK=$(echo ${IP} | cut -f3 -d.)

case "${SUBNET}" in
    10)
        orchestrator=ecs
        ;;
    192)
        orchestrator=kubernetes
        ;;
    *)
        orchestrator=unknown
        ;;
esac

if [[ "${orchestrator}" == 'ecs' ]]; then
    case "${NETWORK}" in
      100)
        zone=a
        color=Crimson
        ;;
      101)
        zone=b
        color=CornflowerBlue
        ;;
      102)
        zone=c
        color=LightGreen
        ;;
      *)
        zone=unknown
        color=Yellow
        ;;
    esac
fi

# Regardless of the number of AZ this "case statement" will categorize them in one of three "buckets"
if [[ "${orchestrator}" == 'kubernetes' ]]; then
    case $(( ${NETWORK} % 3 )) in
        0)
          zone=a
          color=Crimson
        ;;
        1)
          zone=b
          color=CornflowerBlue
        ;;
        2)
          zone=c
          color=LightGreen
        ;;
        *)
          zone=unknown
          color=Yellow
        ;;
    esac
fi

if [[ ${orchestrator} == 'unknown' ]]; then
  # zone=$(curl -m2 -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.availabilityZone' | grep -o .$)
  zone=$(TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"` && curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.availabilityZone' | grep -o .$)
fi 

# Am I on ec2 instances?
if [[ ${zone} == "unknown" ]]; then
  # zone=$(curl -m2 -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.availabilityZone' | grep -o .$)
  zone=$(TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"` && curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.availabilityZone' | grep -o .$)
fi

# Still no luck? Perhaps we're running fargate!
if [[ -z ${zone} ]]; then
  zone=$(curl -s ${ECS_CONTAINER_METADATA_URI_V4}/task | jq -r '.AvailabilityZone' | grep -o .$)
fi

export CODE_HASH="$(cat code_hash.txt)"
export IP
export AZ="${IP} in AZ-${zone}"

# exec container command
exec /server
