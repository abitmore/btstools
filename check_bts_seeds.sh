#!/bin/sh

seeds_file=https://raw.githubusercontent.com/bitshares/bitshares-core/master/libraries/egenesis/seed-nodes.txt

seeds=`curl $seeds_file 2>/dev/null | tail -n "+2" | cut -f2 -d'"'`

for seed in ${seeds}; do
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

