#!/bin/sh

api_nodes_file=https://raw.githubusercontent.com/bitshares/bitshares-ui/develop/app/api/apiConfig.js
rpc_query='{"method":"call","id":1,"jsonrpc":"2.0","params":["database","get_dynamic_global_properties",[]]}'

api_nodes=`curl "$api_nodes_file" 2>/dev/null | grep -E "^( )*url" | grep -v fake | cut -f2 -d '"' | grep '^wss://' | cut -c5-`

for node in $api_nodes; do
  # //api.bts.mobi/ws
  printf "%-35s" "wss:$node"
  head_time=`curl --connect-timeout 10 -d "$rpc_query" https:$node 2>/dev/null |jq -M .|grep '"time"'|cut -f4 -d'"'`
  if [ -n "$head_time" ]; then
    head_age=`expr $(date +%s --utc) - $(date +%s --utc -d "$head_time")`
    echo "head age $head_age"
  else
    echo "Down"
  fi
done

for seed in ""; do
  exit
#for seed in ${seeds}; do
  seed_host=`echo $seed|cut -f1 -d':'`;
  seed_port=`echo $seed|cut -f2 -d':'`;

  seed_ips=`dig "$seed_host"|grep -v '^;'|grep -E "IN\s*A"|awk '{print $5}'|sort`
  count=`echo "$seed_ips"|wc -l`
  if [ "$count" = "0" ]; then
    echo "$seed\tDNS lookup failed"
  else
    if [ "$count" = "1" ]; then
      printf "%-32s" $seed
    else
      printf "%s (%d IP addresses)\n" $seed $count
    fi
    for seed_ip in $seed_ips; do
      echo -n "${seed_ip}:${seed_port}\t";
      [ -n "`echo EOF | nc ${seed_ip} $seed_port -w 10 -q 2`" ] && echo Ok || echo Failed
    done
  fi

done

