#!/bin/bash

CONSUL=localhost

readonly lockPath=service/webapp/locks/master
# readonly lastBackupKey=service/webapp/last-backup

consulCommand() {
    consul-cli --quiet --consul="${CONSUL}:8500" $*
}

preStart() {
    logDebug "preStart"

    if [[ -n ${CONSUL_LOCAL_CONFIG} ]]; then
      	echo "$CONSUL_LOCAL_CONFIG" > "/opt/consul/config/local.json"
    fi
}

onStart() {
    logDebug "onStart"

    waitForLeader

    getRegisteredServiceName
    if [[ "${registeredServiceName}" == "webapp" ]]; then

        echo "Getting master address"

        if [[ "$(consulCommand catalog service "webapp" | jq any)" == "true" ]]; then
            # only wait for a healthy service if there is one registered in the catalog
            local i
            for (( i = 0; i < ${MASTER_WAIT_TIMEOUT-60}; i++ )); do
                getServiceAddresses "webapp"
                if [[ ${serviceAddresses} ]]; then
                    break
                fi
                sleep 1
            done
        fi

        if [[ ! ${serviceAddresses} ]]; then
            echo "No healthy master, trying to set this node as master"

            logDebug "Locking ${lockPath}"
            local session=$(consulCommand kv lock "${lockPath}" --ttl=30s --lock-delay=5s)
            echo ${session} > /var/run/webapp-master.sid

            getServiceAddresses "webapp"
            if [[ ! ${serviceAddresses} ]]; then
                echo "Still no healthy master, setting this node as master"

                setRegisteredServiceName "webapp"
                exit 2
            fi

            logDebug "Unlocking ${lockPath}"
            consulCommand kv unlock "${lockPath}" --session="$session"
        fi

    else

        local session=$(< /var/run/webapp-master.sid)
        if [[ "$(consulCommand kv lock "${lockPath}" --ttl=30s --session="${session}")" != "${session}" ]]; then
            echo "This node is no longer the master"

            setRegisteredServiceName "webapp"
            exit 2
        fi

    fi

    if [[ ${serviceAddresses} ]]; then
        echo "Master is ${serviceAddresses}"
    else
        getNodeAddress
        echo "Master is ${nodeAddress} (this node)"
        export MASTER_ADDRESS=${nodeAddress}
    fi
}

waitForLeader() {
    logDebug "Waiting for consul leader"
    local tries=0
    while true
    do
        logDebug "Waiting for consul leader"
        tries=$((tries + 1))
        local leader=$(consulCommand --template="{{.}}" status leader)
        if [[ -n "$leader" ]]; then
            break
        elif [[ $tries -eq 60 ]]; then
            echo "No consul leader"
            exit 1
        fi
        sleep 1
    done
}

getServiceAddresses() {
    local serviceInfo=$(consulCommand health service --passing "$1")
    serviceAddresses=($(echo $serviceInfo | jq -r '.[].Service.Address'))
    logDebug "serviceAddresses $1 ${serviceAddresses[*]}"
}

getRegisteredServiceName() {
    registeredServiceName=$(jq -r '.services[0].name' /etc/containerpilot.json)
}

setRegisteredServiceName() {
    jq ".services[0].name = \"$1\"" /etc/containerpilot.json  > /etc/containerpilot.json.new
    mv /etc/containerpilot.json.new /etc/containerpilot.json
    kill -HUP 1
}

getNodeAddress() {
    nodeAddress=$(ifconfig eth0 | awk '/inet addr/ {gsub("addr:", "", $2); print $2}')
}

logDebug() {
    if [[ "${LOG_LEVEL}" == "DEBUG" ]]; then
        echo "manage: $*"
    fi
}

help() {
    echo "Usage: ./manage.sh preStart       => configure Consul agent"
    echo "       ./manage.sh onStart        => first-run configuration"
}

until
    cmd=$1
    if [[ -z "$cmd" ]]; then
        help
    fi
    shift 1
    $cmd "$@"
    [ "$?" -ne 127 ]
do
    help
    exit
done