#!/bin/sh

seeds_file=https://raw.githubusercontent.com/bitshares/bitshares-core/master/libraries/egenesis/seed-nodes.txt

seeds=`curl $seeds_file 2>/dev/null | tail -n "+2" | cut -f2 -d'"'`

for seed in ${seeds}; do
  seed_host=`echo $seed|cut -f1 -d':'`;
  seed_port=`echo $seed|cut -f2 -d':'`;

  seed_ips=`dig "$seed_host"|grep -v '^;'|grep -E "IN\s*A"|awk '{print $5}'|sort`
  if [ -z "$seed_ips" ]; then
    echo "$seed\t\t\t\tDNS lookup failed"
  else
    count=`echo "$seed_ips"|wc -l`
    if [ "$count" = "1" ]; then
      printf "%-32s" $seed
    else
      printf "%s (%d IP addresses)\n" $seed $count
    fi
    for seed_ip in $seed_ips; do
      printf "%-24s" "${seed_ip}:${seed_port}"
      [ -n "`nc ${seed_ip} $seed_port -w 10 -W 1`" ] && echo Ok || echo Failed
    done
  fi

done
