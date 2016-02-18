#!/usr/bin/env ruby

#require 'bigdecimal'

require_relative "chain2.rb"

####################################################
# get account history
#

def chain2_get_account_history(account, limit)
  r = chain2_command command:"get_account", params:[account]
  stats_obj= r["result"]["statistics"]
  r = chain2_command command:"get_object", params:[stats_obj]
  puts JSON.pretty_generate r["result"]
  op = r["result"][0]["most_recent_op"]
  count = limit
  while count > 0 and op != "2.9.0" do
    r = chain2_command command:"get_object", params:[op]
    #puts r
    op_id = r["result"][0]["operation_id"]
    op = r["result"][0]["next"]
    r = chain2_command command:"get_object", params:[op_id]
    printf "%d=%s\n", (limit - count), (JSON.pretty_generate r["result"][0])
    count -= 1
  end
  
end

#main
if __FILE__ == $0

  if ARGV.length == 0 then
    printf "Usage: %s <account> [limit]\n\n", $0
  else
    limit = 10
    if ARGV.length > 1 and ARGV[1].to_i > 0 then 
      limit = ARGV[1].to_i
    end
    chain2_get_account_history ARGV[0], limit
  end

end

