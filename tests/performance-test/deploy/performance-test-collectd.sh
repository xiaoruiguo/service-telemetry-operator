#!/bin/bash

REL=$(dirname "$0")

COUNT=${COUNT:-180}
HOSTS=${HOSTS:-50}
PLUGINS=${PLUGINS:-1000}
INTERVAL=${INTERVAL:-1}
CONCURRENT=${CONCURRENT:-1}

oc delete job -l app=stf-performance-test || true

echo "*** [INFO] Creating configmaps..."
oc delete configmap/stf-perftest-collectd-config configmap/stf-collectd-perftest-entrypoint-script job/stf-smoketest || true
oc create configmap stf-perftest-collectd-config --from-file ${REL}/config/osp16ish-collectd.conf
oc create configmap stf-collectd-perftest-entrypoint-script --from-file ${REL}/collectd_perftest_entrypoint.sh

for i in $(seq 1 ${CONCURRENT}); do
   oc create -f <(sed  -e "s/<<PREFIX>>/stf-perftest-${i}-/g;
                           s/<<COUNT>>/${COUNT}/g;
                           s/<<HOSTS>>/${HOSTS}/g;
                           s/<<PLUGINS>>/${PLUGINS}/g;
                           s/<<INTERVAL>>/${INTERVAL}/g"\
                           performance-test-job-collectd.yml.template)
done
