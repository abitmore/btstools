#!/bin/sh

# Dependencies:
# - curl
# - jq

CURL="curl --connect-timeout 30 --max-time 60"

api_nodes_file=https://raw.githubusercontent.com/bitshares/bitshares-ui/develop/app/api/apiConfig.js
dgprops_query='{"method":"call","id":1,"jsonrpc":"2.0","params":["database","get_dynamic_global_properties",[]]}'
cprops_query='{"method":"call","id":1,"jsonrpc":"2.0","params":["database","get_chain_properties",[]]}'
mekong61_query='{"method":"call","id":1,"jsonrpc":"2.0","params":["login","get_available_api_sets",[]]}'
suez_query='{"method":"call","id":1,"jsonrpc":"2.0","params":["database","get_required_fees",[[[77,{}]],"1.3.0"]]}'
mainnet_acstats_query='{"method":"call","id":1,"jsonrpc":"2.0","params":["database","get_objects",[["2.6.33015"]]]}'
testnet_acstats_query='{"method":"call","id":1,"jsonrpc":"2.0","params":["database","get_objects",[["2.6.6"]]]}'
mainnet_chain_id="4018d7844c78f6a6c41c6a552b898022310fc5dec06da467ee7905a8dad512c8"
testnet_chain_id="39f5e2ede1f8bc1a3a54a7914414e3779e33193f1f5693510e73cb7a87617447"

api_nodes=`$CURL "$api_nodes_file" 2>/dev/null | grep -E "^( )*url" | grep -v fake | cut -f2 -d '"' | grep '^wss://' | cut -c5-`

for node in $api_nodes; do
  # //api.bts.mobi/ws
  printf "%-37s" "wss:$node"
  head_time=`$CURL -d "$dgprops_query" https:$node 2>/dev/null |jq -M . 2>/dev/null|grep '"time"'|cut -f4 -d'"'`
  if [ -n "$head_time" ]; then
    head_age=`expr $(date +%s --utc) - $(date +%s --utc -d "$head_time")`
    chain_id=`$CURL -d "$cprops_query" https:$node 2>/dev/null |jq -M .|grep '"chain_id"'|cut -f4 -d'"'`
    printf "%-21s" "head age ${head_age} s "
    echo -n "chain_id [${chain_id}] "
    if [ "x$chain_id" = "x$mainnet_chain_id" -o "x$chain_id" = "x$testnet_chain_id" ]; then # BitShares Mainnet or Testnet
      if [ "x$chain_id" = "x$mainnet_chain_id" ]; then # mainnet
        acstats_query=$mainnet_acstats_query
      else
        acstats_query=$testnet_acstats_query
      fi
      fee_op_77=`$CURL -d "$suez_query" https:$node 2>/dev/null`
      fee_op_77_error=`echo $fee_op_77|grep 'error'`
      if [ -z "$fee_op_77_error" ]; then
        printf "%-6s" "7.0.x"
      else
        available_api_sets=`$CURL -d "$mekong61_query" https:$node 2>/dev/null`
        available_api_sets_error=`echo $available_api_sets|grep 'error'`
        if [ -z "$available_api_sets_error" ]; then
          printf "%-6s" "6.1.x"
        else
          printf "%-6s" "6.0.x"
        fi
      fi
      stats=`$CURL -d "$acstats_query" https:$node 2>/dev/null |jq -M .`
      total_ops=`echo "$stats" |grep '"total_ops"'|awk '{print $2}'|cut -f1 -d','`
      removed_ops=`echo "$stats" |grep '"removed_ops"'|awk '{print $2}'|cut -f1 -d','`
      if [ -n "$total_ops" -a -n "$removed_ops" ]; then
        his_ops=$(($total_ops - $removed_ops))
        echo " max_ops_per_account $his_ops"
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
