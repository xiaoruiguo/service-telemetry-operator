#!/bin/bash

for (( i=1; i<= HOSTS; i++ ))
do
    INSTANCE_CONFIG="/tmp/osp16ish-collectd.conf-${i}"
    cp /etc/osp16ish-collectd.conf "${INSTANCE_CONFIG}"
    echo -e "\nHostname \"${HOSTNAME}${i}\"" >> "${INSTANCE_CONFIG}"
    HOSTNAME=${HOSTNAME}${i} /usr/sbin/collectd -C "${INSTANCE_CONFIG}" -f 2>&1 | tee /tmp/collectd_output_${i} &
done

sleep 600