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
def compare_ob_with_acc (ob1:nil, ob2:nil, accounts:{})
  return nil,accounts if ob1.nil? or ob2.nil? or accounts.nil? or accounts.empty?
  if ob1["base"] != ob2["base"] or ob1["quote"] != ob2["quote"] or ob1["source"] == ob2["source"]
    return nil,accounts
  end
  o1 = ob1.clone
  o2 = ob2.clone

  #ret={
  #  "source"=>"chain",
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

  return [o1,o2],accounts
    
end

# compare order books in an array
# max (single) price diff here
# TODO max (total) price*volume diff
def compare_obs_with_acc (order_books:[], accounts:{})
  return if order_books.nil? or order_books.empty? or accounts.nil? or accounts.empty?

  ar = order_books
  acc = accounts

  base = ar[0]["base"]
  quote = ar[0]["quote"]

  acfg = $MY_ACCOUNT_CONFIG
  base_min_balance = acfg[base]["min_balance"]
  quote_min_balance = acfg[quote]["min_balance"]

  # look for max bid price and min ask price
  # delete empty bid market, delete bid market if no enough fund (account < min)
  max_bid = ar.delete_if { |e| e["bids"].empty? || acc[e["source"]].nil? || acc[e["source"]][quote] < quote_min_balance
                         }.each.max_by { |e| e["bids"][0]["price"].to_f }
  min_ask = ar.delete_if { |e| e["asks"].empty? || acc[e["source"]].nil? || acc[e["source"]][base] < base_min_balance
                         }.each.min_by { |e| e["asks"][0]["price"].to_f }

  # compare 
  compare_ob_with_acc ob1:max_bid, ob2:min_ask, accounts:accounts

end

# fetch order books from all markets, and compare between them
def fetch_all_with_acc (quote:"bts",base:"cny",max_orders:5)

  markets = my_compare_markets

  obs = []
  acc = {}

  markets.each do |m|
    begin
    #if "method" == defined? "fetch_"+m
      obs.push send m+"_fetch", quote:quote, base:base, max_orders:max_orders
    #end
    rescue Exception => e
      print "fetch_"+m+" error: "
      puts e
    end
    begin
      account = send m+"_balance"
      acc.store m, account
    rescue Exception => e
      print m+"_blance error: "
      puts e
    end
  end

  #compare_ob obs[0], obs[2]
  compare_obs_with_acc order_books:obs,accounts:acc

end

# calculate profit base on compared result
def calc_profit_with_acc (order_books:[], accounts:{})
    return 0 if order_books.nil? or order_books.empty? or accounts.nil? or accounts.empty?

    obs = order_books
    acc = accounts

    bids = obs[0]["bids"].clone
    asks = obs[1]["asks"].clone
    if bids.empty? # || asks.empty
      return nil
    end

    base = obs[0]["base"]
    quote = obs[0]["quote"]
    max_fill_bid_volume = acc[obs["sell_to"]][quote] 
    max_fill_ask_amount = acc[obs["buy_from"]][base]

    acfg = $MY_ACCOUNT_CONFIG

    #TODO do something if quote != bts
    #TODO fee calculation model needed
    if obs["sell_to"] == "chain" and quote == "bts"
      max_fill_bid_volume -= acfg["bts"]["min_balance"]
    end
    #if obs["buy_from"] == "chain" and quote == "bts"
    #  max_fill_ask_volume -= acfg["bts"]["min_balance"]
    #end

    profit = 0
    volume = 0 #of quote
    amount = 0 #of base
    bid_index = 0
    ask_index = 0
    my_asks = []
    my_bids = []
    while bid_index < bids.size and ask_index < asks.size 
      bid_price = bids[bid_index]["price"].to_f
      ask_price = asks[ask_index]["price"].to_f
      break if bid_price <= ask_price

      bid_volume = bids[bid_index]["volume"].to_f
      ask_volume = asks[ask_index]["volume"].to_f
      min_volume = [bid_volume, ask_volume,  max_fill_bid_volume-volume, (max_fill_ask_amount-amount)/ask_price].each.min

      # calculate profit
      volume += min_volume
      amount += (min_volume*ask_price)
      profit += (min_volume*(bid_price-ask_price))

      # build my orders
      my_ask_item = {"type"=>"ask","price"=>bid_price,"volume"=>min_volume}
      my_bid_item = {"type"=>"bid","price"=>ask_price,"volume"=>min_volume}
      my_asks.push my_ask_item
      my_bids.push my_bid_item

      # break if no more fund
      break if min_volume < bid_volume and min_volume < ask_volume

      # if still have fund
      if bid_volume < ask_volume
        asks[ask_index]["volume"] = ask_volume - min_volume
        bid_index += 1
      elsif bid_volume == ask_volume
        bid_index += 1
        ask_index += 1
      else # if bid_volume > ask_volume
        bids[bid_index]["volume"] = bid_volume - min_volume
        ask_index += 1
      end
    end

    return {
      "volume"=>("%.6f" % volume),
      "amount"=>("%.6f" % amount),
      "profit"=>("%.6f" % profit),
      "buy_from"=>obs[1]["source"],
      "sell_to"=>obs[0]["source"],
      "orders"=>[{
         "source"=>obs[1]["source"],
         "base"=>obs[1]["base"],
         "quote"=>obs[1]["quote"],
         "bids"=>my_bids,
         "asks"=>[]
      }, {
         "source"=>obs[0]["source"],
         "base"=>obs[0]["base"],
         "quote"=>obs[0]["quote"],
         "bids"=>[],
         "asks"=>my_asks
      }]
    }

end

def submit_orders (orders:nil)
  $LOG.info (method(__method__).name) { {"parameters"=>method(__method__).parameters.map { |arg| "#{arg[1]} = #{eval arg[1].to_s}" }.join(', ') } }
  return if orders.nil?
  my_orders = orders["orders"]
  return if my_orders.nil? or my_orders.empty?

  my_orders.each { |o|
    source = o["source"]
    quote = o["quote"]
    base = o["base"]
    ods = o["bids"].concat o["asks"]

    begin
      $LOG.info (method(__method__).name) { "send " + source + "_submit_orders" } 
      print "send ", source+"_submit_orders", orders:ods, quote:quote, base:base 
      puts
      send source+"_submit_orders", orders:ods, quote:quote, base:base 
    rescue Exception => e
      print source, "_submit_orders error: "
      puts e
    end
  }
end

#main
if __FILE__ == $0
  obs,acc = fetch_all_with_acc
  #puts result
  if obs
    my_orders = calc_profit_with_acc order_books:obs,accounts:acc
    if not my_orders.nil?
      submit_orders orders:my_orders
      puts JSON.pretty_generate my_orders
      # sleep for 15 seconds if submitted chain orders
      sleep 15 if my_orders["buy_from"] == "chain" or my_orders["sell_to"] == "chain"
    else
      puts "nil result"
    end
    #puts JSON.pretty_generate obs
  else
    puts "no result"
  end
end
