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
  max_bid = ar.delete_if { |e| e["bids"].empty? || acc[e["source"]].nil? || 
                               acc[e["source"]][quote].nil? || acc[e["source"]][quote] < quote_min_balance
                         }.each.max_by { |e| e["bids"][0]["price"].to_f }
  min_ask = ar.delete_if { |e| e["asks"].empty? || acc[e["source"]].nil? || 
                               acc[e["source"]][base].nil? || acc[e["source"]][base] < base_min_balance
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
      $LOG.error (method(__method__).name) { e } 
      print "fetch_"+m+" error: "
      puts e
    end
    begin
      account = send m+"_balance"
      acc.store m, account
    rescue Exception => e
      $LOG.error (method(__method__).name) { e } 
      print m+"_blance error: "
      puts e
    end
  end

  #compare_ob obs[0], obs[2]
  compare_obs_with_acc order_books:obs,accounts:acc

end

# calculate profit base on compared result
# parameters: order_books[0] contains bids, order_books[1] contains asks
def calc_profit_with_acc (order_books:[], accounts:{})
    return 0 if order_books.nil? or order_books.empty? or accounts.nil? or accounts.empty?

    obs = order_books
    acc = accounts

    #puts obs
    #puts acc

    bids = obs[0]["bids"].clone
    asks = obs[1]["asks"].clone
    if bids.empty? # || asks.empty
      return nil
    end

    base = obs[0]["base"]
    quote = obs[0]["quote"]
    max_fill_bid_volume = acc[obs[0]["source"]][quote] 
    max_fill_ask_amount = acc[obs[1]["source"]][base]

    acfg = $MY_ACCOUNT_CONFIG

    #TODO do something if quote != bts
    #TODO fee calculation model needed
    #if obs[0]["source"] == "chain" and quote == "bts"
    #  max_fill_bid_volume -= acfg["bts"]["min_balance"]
    #end
    #if obs["buy_from"] == "chain" and quote == "bts"
    #  max_fill_ask_volume -= acfg["bts"]["min_balance"]
    #end
    # Keep some balance
    max_fill_bid_volume -= acfg[quote]["min_balance"]
    max_fill_ask_amount -= acfg[base]["min_balance"]

    # adjust bid/ask price to make sure our order execute
    my_bid_price_adjust = 0
    my_ask_price_adjust = 0
    if obs[0]["source"] == "chain"
      my_ask_price_adjust = 0.000001
    end
    if obs[1]["source"] == "chain"
      my_bid_price_adjust = 0.000001
    end

    # in btc38, when we buy volume, we get (volume*0.999)
    my_bid_volume_adjust = 1
    if obs[1]["source"] == "btc38"
      my_bid_volume_adjust = 0.999
    end

    # in btc38, when we sell volume, we get (volume*price*0.999)
    my_ask_amount_adjust = 1
    if obs[0]["source"] == "btc38"
      my_ask_amount_adjust = 0.999
    end

    min_margin = $MY_TRADE_CONFIG["min_profit_margin"]

    profit = 0
    volume = 0 #of quote
    amount = 0 #of base
    my_ask_volume = 0 #of quote
    my_bid_volume = 0 #of quote
    my_ask_amount = 0 #of base
    my_bid_amount = 0 #of base
    bid_index = 0
    ask_index = 0
    my_asks = []
    my_bids = []
    while bid_index < bids.size and ask_index < asks.size 
      bid_price = bids[bid_index]["price"].to_f - my_ask_price_adjust
      ask_price = asks[ask_index]["price"].to_f + my_bid_price_adjust
      break if bid_price <= ask_price * (1+min_margin)

      bid_volume = bids[bid_index]["volume"].to_f # how many others want to buy
      ask_volume = asks[ask_index]["volume"].to_f # how many others want to sell

      my_fill_bid_volume = bid_volume # how many we will give out if fill the bid order
      my_fill_ask_volume = ask_volume * my_bid_volume_adjust # how many we will get if fill the ask order
      my_max_fill_bid_volume = max_fill_bid_volume - my_ask_volume # how many we can sell
      my_max_fill_ask_volume = (max_fill_ask_amount - my_bid_amount) / ask_price * my_bid_volume_adjust
                                                # how many we will get if we can buy all at current price

      # how many volume we will ask
      my_min_ask_volume = [my_fill_bid_volume, my_fill_ask_volume, my_max_fill_bid_volume, my_max_fill_ask_volume].each.min
      # how many volume we will bid. Remark: avoid precision loss
      my_min_bid_volume = 0
      if my_min_ask_volume == my_fill_ask_volume
        my_min_bid_volume = ask_volume
      elsif my_min_ask_volume == my_max_fill_ask_volume
        my_min_bid_volume = (max_fill_ask_amount - my_bid_amount) / ask_price
      else
        my_min_bid_volume = my_min_ask_volume / my_bid_volume_adjust
      end

      # calculate ask/bid volume and amount
      my_ask_volume += my_min_ask_volume
      my_bid_volume += my_min_bid_volume
      my_ask_amount += my_min_ask_volume * bid_price * my_ask_amount_adjust
      my_bid_amount += my_min_bid_volume * ask_price

      # build my orders
      my_ask_item = {"type"=>"ask","price"=>bid_price,"volume"=>my_min_ask_volume}
      my_bid_item = {"type"=>"bid","price"=>ask_price,"volume"=>my_min_bid_volume}
      my_asks.push my_ask_item
      my_bids.push my_bid_item

      # break if no more fund
      break if my_min_ask_volume < my_fill_bid_volume and my_min_ask_volume < my_fill_ask_volume

      # if still have fund
      if my_fill_ask_volume < my_fill_bid_volume
        asks[ask_index]["volume"] = ask_volume - my_min_bid_volume
        bid_index += 1
      elsif my_fill_ask_volume == my_fill_bid_volume
        ask_index += 1
        bid_index += 1
      else #if my_fill_ask_volume > my_fill_bid_volume
        ask_index += 1
        bids[bid_index]["volume"] = bid_volume - my_min_ask_volume
      end

    end #while

    # profit
    profit = my_ask_amount - my_bid_amount

    # hard code here to deal with min_margin limit. TODO optimize
    return nil if my_ask_volume == 0

    # hard code here to avoid too small orders, good practice not only for btc38. TODO optimize. 
    return nil if my_ask_amount < 1.1

    #combine orders with same price
    # combine ask orders
    my_new_asks = []
    my_new_bids = []
    last_price = 0
    last_volume = 0
    my_asks.each { |o|
      if o["price"] == last_price
        last_volume += o["volume"]
      else
        if last_volume > 0
          last_amount = last_price * last_volume
          # hard code here to avoid btc38 one CNY limit. TODO optimize. 
          # check every order 
          if last_amount < 1.1 and obs[0]["source"] == "btc38"
            # if amount too small, add volume of this order to next order. do nothing here
          else
            my_ask_item = {"type"=>"ask","price"=>last_price,"volume"=>last_volume}
            my_new_asks.push my_ask_item
            last_volume = 0
          end
        end
        last_price = o["price"]
        last_volume += o["volume"]
      end
    }
    ignore_ask_volume = 0
    if last_volume > 0
      last_amount = last_price * last_volume
      # hard code here to avoid btc38 one CNY limit. TODO optimize. 
      # check every order 
      if last_amount < 1.1 and obs[0]["source"] == "btc38"
        # if amount too small, and no more order, ignore this order
        ignore_ask_volume = last_volume
      else
        my_ask_item = {"type"=>"ask","price"=>last_price,"volume"=>last_volume}
        my_new_asks.push my_ask_item
      end
    end
    # combine bid orders
    last_price = 0
    last_volume = 0
    my_bid_volume_combine_sum = 0
    my_bid_volume_combine_max = my_bid_volume - ignore_ask_volume / my_bid_volume_adjust
    my_bids.each { |o|
      bid_end = false
      if my_bid_volume_combine_sum + o["volume"] >= my_bid_volume_combine_max
        bid_end = true
        o["volume"] = my_bid_volume_combine_max - my_bid_volume_combine_sum
      end
      my_bid_volume_combine_sum += o["volume"]
      if o["price"] == last_price
        last_volume += o["volume"]
      else
        if last_volume > 0
          last_amount = last_price * last_volume
          # hard code here to avoid btc38 one CNY limit. TODO optimize. 
          # check every order 
          if last_amount < 1.1 and obs[1]["source"] == "btc38"
            # if amount too small, add volume of this order to next order. do nothing here
          else
            my_bid_item = {"type"=>"bid","price"=>last_price,"volume"=>last_volume}
            my_new_bids.push my_bid_item
            last_volume = 0
          end
        end
        last_price = o["price"]
        last_volume += o["volume"]
      end
      break if bid_end
    }
    ignore_bid_volume = 0
    if last_volume > 0
      last_amount = last_price * last_volume
      # hard code here to avoid btc38 one CNY limit. TODO optimize. 
      # check every order 
      if last_amount < 1.1 and obs[1]["source"] == "btc38"
        # if amount too small, and no more order, ignore this order
        ignore_bid_volume = last_volume
      else
        my_bid_item = {"type"=>"bid","price"=>last_price,"volume"=>last_volume}
        my_new_bids.push my_bid_item
      end
    end
    # adjust ask orders again if ignored at least one bid order
    if ignore_bid_volume > 0
      ignore_ask_volume = ignore_bid_volume * my_bid_volume_adjust
      ask_volume_to_ignore = ignore_ask_volume 
      for i in ((my_new_asks.length-1)..0)
        o = my_new_asks[i]
        if o["volume"] > ask_volume_to_ignore
          o["volume"] -= ask_volume_to_ignore
          break
        else
          ask_volume_to_ignore -= o["volume"]
          my_new_asks.delete_at i
        end
        break if ask_volume_to_ignore <= 0
      end
    end

    return {
      "volume"=>("%.6f" % (my_ask_volume - ignore_ask_volume) ),
      "amount"=>("%.6f" % my_bid_amount), # TODO decuct ignored amount
      "profit"=>("%.6f" % profit), # TODO deduct ignored amount
      "buy_from"=>obs[1]["source"],
      "sell_to"=>obs[0]["source"],
      "orders"=>[{
         "source"=>obs[1]["source"],
         "base"=>obs[1]["base"],
         "quote"=>obs[1]["quote"],
         "bids"=>my_new_bids,
         "asks"=>[]
      }, {
         "source"=>obs[0]["source"],
         "base"=>obs[0]["base"],
         "quote"=>obs[0]["quote"],
         "bids"=>[],
         "asks"=>my_new_asks
      }]
    }

end

def submit_orders (orders:nil)
  $LOG.info (method(__method__).name) { {"parameters"=>method(__method__).parameters.map { |arg| "#{arg[1]} = #{eval arg[1].to_s}" }.join(', ') } }
  return if orders.nil?
  my_orders = orders["orders"]
  return if my_orders.nil? or my_orders.empty?

  my_orders = my_orders.clone
  #TODO buy before sell? or yunbi/BTC38 before chain?
  #my_orders.sort_by! { |o| $MY_TRADE_ORDER[o["source"]] }

  my_orders.each { |o|
    source = o["source"]
    quote = o["quote"]
    base = o["base"]
    ods = o["bids"].concat o["asks"]
    response = nil

    begin
      $LOG.debug (method(__method__).name) { "send " + source + "_submit_orders" } 
      print "send ", source+"_submit_orders", orders:ods, quote:quote, base:base 
      puts
      response = send source+"_submit_orders", orders:ods, quote:quote, base:base 

    rescue Exception => e
      $LOG.error (method(__method__).name) { e } 
      print source, "_submit_orders error: "
      puts e
      return #return if error
    end
  }
end

#main
if __FILE__ == $0
 begin
  obs,acc = fetch_all_with_acc
  #puts result
  if acc
    balances_sum = {}
    #puts acc
    #acc.each {|market,balances| puts a}
    acc.each { |market,balances| balances_sum.merge! (balances) {|key,oldval,newval| oldval + newval} }
    puts JSON.pretty_generate balances_sum.delete_if { |key,value| value == 0.0 or key == "btsx" }
  end
  if obs
    my_orders = calc_profit_with_acc order_books:obs,accounts:acc
    if not my_orders.nil?
      submit_orders orders:my_orders
      puts JSON.pretty_generate my_orders
      # sleep 15 seconds if submitted chain orders (wait for a block)
      if my_orders["buy_from"] == "chain" or my_orders["sell_to"] == "chain"
        sleep 15
      # sleep 60 seconds if submitted btc38 orders (btc38 order book refresh every 15 seconds, but sometimes longer)
      elsif my_orders["buy_from"] == "btc38" or my_orders["sell_to"] == "btc38"
        sleep 60
      else
        sleep 5
      end
    else
      puts "nil result"
    end
    #puts JSON.pretty_generate obs
  else
    puts "no result"
  end
 rescue Exception => e
  $LOG.error ("compare_with_acc.main") { e } 
 end
end
