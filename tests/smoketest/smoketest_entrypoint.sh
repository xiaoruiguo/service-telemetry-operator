#!/bin/sh
set -e

# Executes inside the test harness container to start collectd and look for resulting metrics in prometheus
PROMETHEUS=${PROMETHEUS:-"prometheus-operated:9090"}
ELASTICSEARCH=${ELASTICSEARCH:-"elasticsearch-es-http:9200"}
ELASTICSEARCH_AUTH_PASS=${ELASTICSEARCH_AUTH_PASS:-""}
CLOUDNAME=${CLOUDNAME:-"smoke1"}
POD=$(hostname)

# Render our config template
sed -e "s/<<CLOUDNAME>>/${CLOUDNAME}/" /etc/minimal-collectd.conf.template > /tmp/collectd.conf

echo "My pod is: ${POD}"

echo "Using this collectd.conf:"
cat /tmp/collectd.conf

# Run collectd in foreground mode to generate some metrics
/usr/sbin/collectd -C /tmp/collectd.conf -f 2>&1 | tee /tmp/collectd_output &

# Wait until collectd appears to be up and running
retries=3
until [ $retries -eq 0 ] || grep "Initialization complete, entering read-loop" /tmp/collectd_output; do
  retries=$((retries-1))
  echo "Sleeping for 3 seconds waiting for collectd to enter read-loop"
  sleep 3
done

# Sleeping to collect 1m of actual metrics
sleep 60

echo "List of metric names for debugging..."
curl -g "${PROMETHEUS}/api/v1/label/__name__/values" 2>&2 | tee /tmp/label_names
echo; echo

# Checks that the metrics actually appear in prometheus
echo "Checking for recent CPU metrics..."
curl -g "${PROMETHEUS}/api/v1/query?" --data-urlencode 'query=sa_collectd_cpu_total{cpu="0",type="user",service="saf-default-telemetry-smartgateway",exported_instance="'"${POD}"'"}[1m]' 2>&2 | tee /tmp/query_output
echo; echo

# The egrep exit code is the result of the test and becomes the container/pod/job exit code
grep -E '"result":\[{"metric":{"__name__":"sa_collectd_cpu_total","cpu":"0","endpoint":"prom-http","exported_instance":"'"${POD}"'","service":"saf-default-telemetry-smartgateway","type":"user"},"values":\[\[.+,".+"\]' /tmp/query_output
metrics_result=$?

echo "Get documents for this test from ElasticSearch..."
DOCUMENT_HITS=$(curl -sk -u "elastic:${ELASTICSEARCH_AUTH_PASS}" -X GET "https://${ELASTICSEARCH}/_search" -H 'Content-Type: application/json' -d'{
  "query": {
    "bool": {
      "must": [
        { "match": { "labels.instance":   "'${CLOUDNAME}'" }}
      ],
      "filter": [
        { "range" : { "startsAt" : { "gte" : "now-1m", "lt" : "now" } } }
      ]
    }
  }
}' | python -c "import sys, json; parsed = json.load(sys.stdin); print(parsed['hits']['total']['value'])")

echo "Found ${DOCUMENT_HITS} documents"

echo; echo

# check if we got documents back for this test
events_result=1
if [ "$DOCUMENT_HITS" -gt "0" ]; then
    events_result=0
fi

if [ "$metrics_result" = "0" ] && [ "$events_result" = "0" ]; then
    exit 0
else
    exit 1
fi
