#!/bin/sh

# Dependencies:
# - curl
# - jq

CURL="curl --connect-timeout 10 --max-time 20"

api_nodes_file=https://raw.githubusercontent.com/bitshares/bitshares-ui/develop/app/api/apiConfig.js
dgprops_query='{"method":"call","id":1,"jsonrpc":"2.0","params":["database","get_dynamic_global_properties",[]]}'
cprops_query='{"method":"call","id":1,"jsonrpc":"2.0","params":["database","get_chain_properties",[]]}'
mainnet_acstats_query='{"method":"call","id":1,"jsonrpc":"2.0","params":["database","get_objects",[["2.6.33015"]]]}'
testnet_acstats_query='{"method":"call","id":1,"jsonrpc":"2.0","params":["database","get_objects",[["2.6.6"]]]}'
mainnet_chain_id="4018d7844c78f6a6c41c6a552b898022310fc5dec06da467ee7905a8dad512c8"
testnet_chain_id="39f5e2ede1f8bc1a3a54a7914414e3779e33193f1f5693510e73cb7a87617447"

api_nodes=`$CURL "$api_nodes_file" 2>/dev/null | grep -E "^( )*url" | grep -v fake | cut -f2 -d '"' | grep '^wss://' | cut -c5-`

for node in $api_nodes; do
  # //api.bts.mobi/ws
  printf "%-35s" "wss:$node"
  head_time=`$CURL -d "$dgprops_query" https:$node 2>/dev/null |jq -M . 2>/dev/null|grep '"time"'|cut -f4 -d'"'`
  if [ -n "$head_time" ]; then
    head_age=`expr $(date +%s --utc) - $(date +%s --utc -d "$head_time")`
    chain_id=`$CURL -d "$cprops_query" https:$node 2>/dev/null |jq -M .|grep '"chain_id"'|cut -f4 -d'"'`
    echo -n "head age $head_age s\t chain_id [$chain_id]"
    if [ "x$chain_id" = "x$mainnet_chain_id" -o "x$chain_id" = "x$testnet_chain_id" ]; then # BitShares Mainnet or Testnet
      if [ "x$chain_id" = "x$mainnet_chain_id" ]; then # mainnet
        acstats_query=$mainnet_acstats_query
      else
        acstats_query=$testnet_acstats_query
      fi
      stats=`$CURL -d "$acstats_query" https:$node 2>/dev/null |jq -M .`
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
