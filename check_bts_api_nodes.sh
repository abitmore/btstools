#!/bin/sh

api_nodes_file=https://raw.githubusercontent.com/bitshares/bitshares-ui/develop/app/api/apiConfig.js
dgprops_query='{"method":"call","id":1,"jsonrpc":"2.0","params":["database","get_dynamic_global_properties",[]]}'
cprops_query='{"method":"call","id":1,"jsonrpc":"2.0","params":["database","get_chain_properties",[]]}'
acstats_query='{"method":"call","id":1,"jsonrpc":"2.0","params":["database","get_objects",[["2.6.33015"]]]}'

api_nodes=`curl "$api_nodes_file" 2>/dev/null | grep -E "^( )*url" | grep -v fake | cut -f2 -d '"' | grep '^wss://' | cut -c5-`

for node in $api_nodes; do
  # //api.bts.mobi/ws
  printf "%-35s" "wss:$node"
  head_time=`curl --connect-timeout 10 -d "$dgprops_query" https:$node 2>/dev/null |jq -M . 2>/dev/null|grep '"time"'|cut -f4 -d'"'`
  if [ -n "$head_time" ]; then
    head_age=`expr $(date +%s --utc) - $(date +%s --utc -d "$head_time")`
    chain_id=`curl --connect-timeout 10 -d "$cprops_query" https:$node 2>/dev/null |jq -M .|grep '"chain_id"'|cut -f4 -d'"'`
    echo -n "head age $head_age s\t chain_id [$chain_id]"
    if [ "x$chain_id" = "x4018d7844c78f6a6c41c6a552b898022310fc5dec06da467ee7905a8dad512c8" ]; then # BitShares Mainnet
      stats=`curl --connect-timeout 10 -d "$acstats_query" https:$node 2>/dev/null |jq -M .`
      total_ops=`echo "$stats" |grep '"total_ops"'|awk '{print $2}'|cut -f1 -d','`
      removed_ops=`echo "$stats" |grep '"removed_ops"'|awk '{print $2}'|cut -f1 -d','`
      if [ -n "$total_ops" -a -n "$removed_ops" ]; then
        his_ops=$(($total_ops - $removed_ops))
        echo "\tmax_ops_per_account $his_ops"
      else
        echo
      fi
    else
      echo
    fi
  else
    echo "Down"
  fi
done
