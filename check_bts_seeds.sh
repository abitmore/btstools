#!/bin/bash

BRANCH=master
if [ -n "$1" ]; then
  BRANCH=$1
fi

if [ "${BRANCH}" == "testnet" ]; then
  seeds_file=https://raw.githubusercontent.com/bitshares/bitshares-core/${BRANCH}/libraries/egenesis/seed-nodes-testnet.txt
else
  seeds_file=https://raw.githubusercontent.com/bitshares/bitshares-core/${BRANCH}/libraries/egenesis/seed-nodes.txt
fi

seeds=`curl $seeds_file 2>/dev/null | grep -v '^//' | cut -f2 -d'"'`

for seed in ${seeds}; do
  seed_host=`echo $seed|cut -f1 -d':'`;
  seed_port=`echo $seed|cut -f2 -d':'`;

  seed_ips=`dig "$seed_host"|grep -v '^;'|grep -E "IN\s*A"|awk '{print $5}'|sort -V`
  if [ -z "$seed_ips" ]; then
    printf "%-62s" $seed
    echo "DNS lookup failed"
  else
    count=`echo "$seed_ips"|wc -l`
    if [ "$count" = "1" ]; then
      printf "%-38s" $seed
    else
      printf "%s (%d IP addresses)\n" $seed $count
    fi
    for seed_ip in $seed_ips; do
      printf "%-24s" "${seed_ip}:${seed_port}"
      [[ $( nc ${seed_ip} $seed_port -w 10 -W 1 | wc -c ) -ne 0 ]] && echo Ok || echo Failed
    done
  fi

done
