#!/usr/bin/env ruby

require 'bigdecimal'

require_relative "chain.rb"

def list_covers (currency)
  print currency," ",Time.now.utc.to_s,"\n"
  r = chain_command command:"blockchain_market_list_covers", params:[currency, 'BTS']
  printf "%15s%20s%20s%20s%20s\n", "expiration", "usd_balance", "margin_call_price", "owner", "interest"
  order_list = []
  r["result"].each { |o|
    price_js = o["market_index"]["order_price"]
    price = 0
    if not price_js.nil?
      price = (BigDecimal.new(price_js["ratio"]) * 10.0).to_f
    end
    interest = (BigDecimal.new(o["interest_rate"]["ratio"]) * 100.0).to_f
    interest_s = o["interest_rate"]["ratio"]
    usd_balance = o["state"]["balance"]/10000.0
    bts_balance = o["collateral"]/100000.0
    expiration = o["expiration"]
    owner = o["market_index"]["owner"]
    order_list.push ({"usd_balance"=>usd_balance, "price"=>price, "interest"=>interest, "owner"=>owner, "interest_s"=>interest_s, "expiration"=>expiration })
  }
  #new_list = order_list
  new_list = order_list.sort { |o,b| o["expiration"] <=> b["expiration"] }
  #new_list = order_list.sort { |o,b| Time.new(b["expiration"]) <=> Time.new(o["expiration"])}
  #new_list = (order_list.sort { |o| o["usd_balance"] }).reverse
  #new_list = (order_list.sort { |o| o["interest"] }).reverse
  new_list.each { |o|
    ex = Time.parse(o["expiration"]+' +0000') 
    if ex < Time.now
      #o["expiration"] = "  Expired          "
      o["expiration"] += "**"
    end
    printf "%s      %f         %f         %s                %s\n", o["expiration"], o["usd_balance"], o["price"], o["owner"], o["interest_s"]
  }
  
end

#main
if __FILE__ == $0

  list_covers  ARGV[0]

end

