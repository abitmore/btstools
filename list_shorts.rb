#!/usr/bin/env ruby

require 'bigdecimal'

require_relative "chain.rb"

def list_shorts (currency)
  puts currency
  r = chain_command command:"blockchain_market_list_shorts", params:[currency]
  printf "%10s%20s%20s%40s\n", "bts_balance", "price_limit", "owner", "interest"
  order_list = []
  r["result"].each { |o|
    price_js = o["state"]["limit_price"]
    price_limit = 0
    if not price_js.nil?
      price_limit = (BigDecimal.new(price_js["ratio"]) * 10.0).to_f
    end
    interest = (BigDecimal.new(o["interest_rate"]["ratio"]) * 100.0).to_f
    interest_s = o["interest_rate"]["ratio"]
    bts_balance = o["collateral"]/100000.0
    owner = o["market_index"]["owner"]
    order_list.push ({"bts_balance"=>bts_balance, "price_limit"=>price_limit, "interest"=>interest, "owner"=>owner, "interest_s"=>interest_s})
  }
  new_list = order_list.sort { |o| o["interest"] }.reverse
  new_list.each { |o|
    printf "%f         %f         %s                %s\n", o["bts_balance"], o["price_limit"], o["owner"], o["interest_s"]
  }
  
end

#main
if __FILE__ == $0

  list_shorts  ARGV[0]

end

