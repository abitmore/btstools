#!/usr/bin/env ruby

require_relative "yunbi"
require_relative "btc38"
require_relative "bter"
require_relative "chain"
require_relative "config"

###########################################
# compare all markets and look for chances
#

# compare two order books
# TODO re-design ob into a class
def compare_ob (ob1, ob2)
  if ob1["base"] != ob2["base"] or ob1["quote"] != ob2["quote"] or ob1["source"] == ob2["source"]
    return nil
  end
  o1 = ob1.clone
  o2 = ob2.clone

  #ret={
  #  "source"=>"BLOCK CHAIN",
  #  "base"=>a2,
  #  "quote"=>a1,
  #  "asks"=>asks_new,
  #  "bids"=>bids_new
  #}

  # delete the orders won't match
  # the result may overlap
  o1["asks"].delete_if { |e| o2["bids"].empty? || e["price"].to_f >= o2["bids"][0]["price"].to_f }
  o1["bids"].delete_if { |e| o2["asks"].empty? || e["price"].to_f <= o2["asks"][0]["price"].to_f }
  o2["asks"].delete_if { |e| o1["bids"].empty? || e["price"].to_f >= o1["bids"][0]["price"].to_f }
  o2["bids"].delete_if { |e| o1["asks"].empty? || e["price"].to_f <= o1["asks"][0]["price"].to_f }

  return [o1,o2]
    
end

# compare order books in an array
# max (single) price diff here
# TODO max (total) price*volume diff
def compare_obs (ar)
  # look for max bid price and min ask price
  max_bid = ar.delete_if { |e| e["bids"].empty? }.each.max_by { |e| e["bids"][0]["price"].to_f }
  min_ask = ar.delete_if { |e| e["asks"].empty? }.each.min_by { |e| e["asks"][0]["price"].to_f }

  # compare 
  compare_ob max_bid, min_ask

end

# fetch order books from all markets, and compare between them
def fetch_all (a1="bts",a2="cny",max_orders=5)

  markets = my_compare_markets

  obs = []

  markets.each do |m|
    begin
    #if "method" == defined? "fetch_"+m
      obs.push send "fetch_"+m, a1, a2, max_orders
    #end
    rescue Exception => e
      print "fetch_"+m+" error: "
      puts e
    end
  end

  #compare_ob obs[0], obs[2]
  compare_obs obs

end

# calculate profit base on compared result
def calc_profit (obs)
    bids = obs[0]["bids"].clone
    asks = obs[1]["asks"].clone
    if bids.empty? # || asks.empty
      return 0
    end

    profit = 0
    volume = 0
    bid_index = 0
    ask_index = 0
    while bid_index < bids.size && ask_index < asks.size 
      bid_price = bids[bid_index]["price"].to_f
      ask_price = asks[ask_index]["price"].to_f
      if bid_price <= ask_price
        break
      end
      bid_volume = bids[bid_index]["volume"].to_f
      ask_volume = asks[ask_index]["volume"].to_f
      if bid_volume < ask_volume
        profit += (bid_volume*(bid_price-ask_price))
        volume += bid_volume
        asks[ask_index]["volume"] = ask_volume - bid_volume
        bid_index += 1
      elsif bid_volume == ask_volume
        profit += (bid_volume*(bid_price-ask_price))
        volume += bid_volume
        bid_index += 1
        ask_index += 1
      else # if bid_volume > ask_volume
        profit += (ask_volume*(bid_price-ask_price))
        volume += ask_volume
        bids[bid_index]["volume"] = bid_volume - ask_volume
        ask_index += 1
      end
    end

    return {"volume"=>("%.6f" % volume), "profit"=>("%.6f" % profit), obs[1]["source"]=>obs[0]["source"]}

end

#main
if __FILE__ == $0
  result = fetch_all
  #puts result
  if result
    puts calc_profit result
    puts JSON.pretty_generate result
  else
    puts "no result"
  end
end
