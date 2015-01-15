#!/usr/bin/env ruby

require "httpclient"
require "json"

require_relative "config"
require_relative "myfunc"
require_relative "mylogger"

####################################
# blockchain
#

# TODO write a class/function to communicate with rpc server

def chain_post (data:{})
  $LOG.debug (method(__method__).name) { {"parameters"=>method(__method__).parameters.map { |arg| "#{arg[1]} = #{eval arg[1].to_s}" }.join(', ') } }
  if data.nil? or data.empty?
    return
  end

  client = HTTPClient.new 
  client.connect_timeout=5
  client.receive_timeout=5
  
  myconfig = my_chain_config
  uri  = myconfig["uri"]
  user = myconfig["user"]
  pass = myconfig["pass"]
 
  client.set_auth uri, user, pass
 
  begin
    response = client.post uri, data.to_json, nil
    #$LOG.debug (method(__method__).name) { response }
    response_content = response.content
    $LOG.debug (method(__method__).name) { {"response_content" => response_content} }
    response_json = JSON.parse response_content
    if not response_json["error"].nil?
      #$LOG.debug (method(__method__).name) { response_json["error"] }
      #response_content = response.body
    end
    return response_json
  rescue Exception => e
    print "chain_post error: "
    puts e
  end
end

# params is an array
def chain_command (command:nil, params:nil)
  $LOG.debug (method(__method__).name) { {"parameters"=>method(__method__).parameters.map { |arg| "#{arg[1]} = #{eval arg[1].to_s}" }.join(', ') } }
  if command.nil? or params.nil? 
    return
  end
  #request_data= '{"jsonrpc": "2.0", "method": "blockchain_get_asset", "params":["'+quote.upcase+'"], "id":1}'
  data = {
    "jsonrpc" => "2.0",
    "method"  => command,
    "params"  => params,
    "id"      => 0
  }
  return chain_post data:data
end

def fetch_chain (quote="bts", base="cny", max_orders=5)
  chain_fetch quote:quote, base:base, max_orders:max_orders
end

def chain_fetch (quote:"bts", base:"cny", max_orders:5)

  response_json = chain_command command:"blockchain_get_asset", params:[quote.upcase]
  quote_precision = response_json["result"]["precision"]

  response_json = chain_command command:"blockchain_get_asset", params:[base.upcase]
  base_precision = response_json["result"]["precision"]

  response_json = chain_command command:"blockchain_median_feed_price", params:[base.upcase]
  feed_price = response_json["result"]

  response_json = chain_command command:"blockchain_market_order_book", params:[base.upcase, quote.upcase]
  ob = response_json["result"]
  #puts JSON.pretty_generate ob["result"]
  
  #ask orders and cover orders are in same array. filter invalid short orders here. TODO maybe wrong logic here
  asks = ob[1].delete_if {|e| e["type"] == "cover_order" and
                              feed_price > e["market_index"]["order_price"]["ratio"].to_f*quote_precision/base_precision
                       }.sort_by {|e| e["market_index"]["order_price"]["ratio"].to_f}.first(max_orders)
  bids = ob[0].sort_by {|e| e["market_index"]["order_price"]["ratio"].to_f}.reverse.first(max_orders)
  
  #asks_new=Hash[*asks.map["price","volume"]]
  asks_new=[]
  bids_new=[]
  asks.each do |e|
    item = {
      "price"=>e["market_index"]["order_price"]["ratio"].to_f*quote_precision/base_precision,
      "volume"=>e["state"]["balance"].to_f/quote_precision
    }
    #item["volume"] /= item["price"]
    asks_new.push item
  end
  bids.each do |e|
    item = {
      "price"=>e["market_index"]["order_price"]["ratio"].to_f*quote_precision/base_precision,
      "volume"=>e["state"]["balance"].to_f/base_precision
    }
    item["volume"] /= item["price"]
    bids_new.push item
  end
  
  #return
  ret={
    "source"=>"chain",
    "base"=>base,
    "quote"=>quote,
    "asks"=>asks_new,
    "bids"=>bids_new
  }
end

def chain_balance

  account = my_chain_config["account"]
  response_json = chain_command command:"wallet_account_balance", params:[account]
  balances = response_json["result"]
  #puts balances

=begin
  "result":[
    [ "account1",
      [
        [asset_id, balance], ..., [asset_id, balance]
      ]
    ],
    ...
    [ "account2" ...
    ]
  ]
=end 

  my_balance = Hash.new
  balances.each { |e| 
      account_info = Hash.new
      account_name = e[0]
      assets = e[1]
      assets.each { |a|
          asset_id = a[0]
          asset_balance = a[1]

          asset_response_json = chain_command command:"blockchain_get_asset", params:[asset_id]
          asset_precision = asset_response_json["result"]["precision"]
          asset_symbol = asset_response_json["result"]["symbol"].downcase

          account_info.store asset_symbol, asset_balance.to_f / asset_precision
      }
      my_balance.store account_name, account_info
  }

  return my_balance[account]

end

def chain_orders (quote:"bts", base:"cny", type:"all")
  ret = {
      "source"=>"chain",
      "base"=>base,
      "quote"=>quote,
      "asks"=>[],
      "bids"=>[]
  }

  #account = my_chain_config["account"]
  response_json = chain_command command:"wallet_market_order_list", params:[base.upcase, quote.upcase]
  orders = response_json["result"]
  #puts orders

  if orders.empty?
    return ret
  end

  response_json = chain_command command:"blockchain_get_asset", params:[quote.upcase]
  quote_precision = response_json["result"]["precision"]

  response_json = chain_command command:"blockchain_get_asset", params:[base.upcase]
  base_precision = response_json["result"]["precision"]

  need_ask = ("all" == type or "ask" == type)
  need_bid = ("all" == type or "bid" == type)
  asks_new=[]
  bids_new=[]

=begin
    [
      "9c8d305ffe11c880b85b66928979b1e251e108fb",
      {
        "type": "ask_order",
        "market_index": {
          "order_price": {
            "ratio": "998877.0000345",
            "quote_asset_id": 14,
            "base_asset_id": 0
          },
          "owner": "BTS2TgDZ3nNwn9u6yfqaQ2o63bif15U8Y4En"
        },
        "state": {
          "balance": 314159,
          "limit_price": null,
          "last_update": "2015-01-06T02:01:40"
        },
        "collateral": null,
        "interest_rate": null,
        "expiration": null
      }
    ],
=end

  orders.each do |e|
    order_id = e[0]
    order_type = e[1]["type"]
    order_price = e[1]["market_index"]["order_price"]["ratio"].to_f * quote_precision / base_precision
    if "bid_order" == order_type and need_bid
      order_volume = e[1]["state"]["balance"].to_f / base_precision / order_price
      item = {"id"=>e[0], "price"=>order_price, "volume"=>order_volume}
      bids_new.push item
    elsif "ask_order" == order_type and need_ask
      order_volume = e[1]["state"]["balance"].to_f / quote_precision
      item = {"id"=>e[0], "price"=>order_price, "volume"=>order_volume}
      asks_new.push item
    end
  end

  asks_new.sort_by! {|e| e["price"].to_f}
  bids_new.sort_by! {|e| e["price"].to_f}.reverse!

  ret["asks"]=asks_new
  ret["bids"]=bids_new

  return ret

end

# parameter base is to be compatible with btc38
def chain_cancel_order (id:nil, base:"cny")
  #$LOG.debug (self.class.name.to_s+'.'+method(__method__).name) { method(__method__).parameters.map }
  #$LOG.debug (method(__method__).name) { method(__method__).parameters.map { |arg| "#{arg} = #{eval arg}" }.join(', ')}
  $LOG.info (method(__method__).name) { {"parameters"=>method(__method__).parameters.map { |arg| "#{arg[1]} = #{eval arg[1].to_s}" }.join(', ') } }
  if id.nil?
    return
  end

  # the API wallet_market_cancel_order is deprecated, so call another method
  chain_cancel_orders ids:[id], base:base
  #response_json = chain_command command:"wallet_market_cancel_order", params:[id]
  #result = response_json["result"]

end

# parameter base is to be compatible with btc38
def chain_cancel_orders (ids:[], base:"cny")
  $LOG.info (method(__method__).name) { {"parameters"=>method(__method__).parameters.map { |arg| "#{arg[1]} = #{eval arg[1].to_s}" }.join(', ') } }
  if ids.nil? or ids.empty?
    return
  end

  response_json = chain_command command:"wallet_market_cancel_orders", params:[ids]
  #result = response_json["result"]
  if not response_json["error"].nil?
    $LOG.error (method(__method__).name) { JSON.pretty_generate response_json["error"] }
  end

  #return result
end

def chain_cancel_orders_by_type (quote:"bts", base:"cny", type:"all")
  orders = chain_orders quote:quote, base:base, type:type
  ids = orders["bids"].concat(orders["asks"]).collect { |e| e["id"] }
  puts ids.to_s
  chain_cancel_orders ids:ids
end

def chain_cancel_all_orders (quote:"bts", base:"cny")
  chain_cancel_orders_by_type quote:quote, base:base, type:"all"
end

def chain_new_order (quote:"bts", base:"cny", type:nil, price:nil, volume:nil, cancel_order_id:nil)
  $LOG.info (method(__method__).name) { {"parameters"=>method(__method__).parameters.map { |arg| "#{arg[1]} = #{eval arg[1].to_s}" }.join(', ') } }
  if "bid" == type
    chain_bid quote:quote, base:base, price:price, volume:volume
  elsif "ask" == type
    chain_ask quote:quote, base:base, price:price, volume:volume
  elsif "cancel" == type
    chain_cancel_order id:cancel_order_id
  end
end

def chain_submit_orders (orders:[],quote:"bts",base:"cny")
  $LOG.info (method(__method__).name) { {"parameters"=>method(__method__).parameters.map { |arg| "#{arg[1]} = #{eval arg[1].to_s}" }.join(', ') } }

  if orders.nil? or orders.empty?
    return nil
  end

  cancel_order_ids = []
  new_orders = []
  account = my_chain_config["account"]

  orders.each { |e|
    case e["type"]
    when "cancel"
      cancel_order_ids.push e["id"]
    when "ask"
      new_orders.push ["ask_order", [account, e["volume"], (e["quote"] or quote).upcase, e["price"], (e["base"] or base).upcase]]
    when "bid"
      new_orders.push ["bid_order", [account, e["volume"], (e["quote"] or quote).upcase, e["price"], (e["base"] or base).upcase]]
    end
  }

  #wallet_market_batch_update <cancel_order_ids> <new_orders> <sign>
  #param2 example: [['bid_order', ['myname', quantity, 'BTS', price, 'USD']], ['bid_order', ['myname', 124, 'BTS', 224, 'CNY']], ['ask_order', ['myname', 524, 'BTS', 624, 'CNY']], ['ask_order', ['myname', 534, 'BTS', 634, 'CNY']]]
  #wallet_market_submit_bid <from_account_name> <quantity> <quantity_symbol> <base_price> <base_symbol> [allow_stupid_bid] 
  response_json = chain_command command:"wallet_market_batch_update", params:[cancel_order_ids, new_orders, true]

  if not response_json["error"].nil?
    $LOG.error (method(__method__).name) { JSON.pretty_generate response_json["error"] }
    return response_json["error"]
  else
    return response_json["result"]
  end

end

def chain_bid (quote:"bts", base:"cny", price:nil, volume:nil)
  $LOG.info (method(__method__).name) { {"parameters"=>method(__method__).parameters.map { |arg| "#{arg[1]} = #{eval arg[1].to_s}" }.join(', ') } }

  if price.nil? or volume.nil?
    return nil
  end

  account = my_chain_config["account"]
  #wallet_market_submit_bid <from_account_name> <quantity> <quantity_symbol> <base_price> <base_symbol> [allow_stupid_bid] 
  response_json = chain_command command:"wallet_market_submit_bid", params:[account, volume, quote.upcase, price, base.upcase]

  if not response_json["error"].nil?
    $LOG.error (method(__method__).name) { JSON.pretty_generate response_json["error"] }
    return response_json["error"]
  else
    return response_json["result"]
  end

end

def chain_ask (quote:"bts", base:"cny", price:nil, volume:nil)
  $LOG.info (method(__method__).name) { {"parameters"=>method(__method__).parameters.map { |arg| "#{arg[1]} = #{eval arg[1].to_s}" }.join(', ') } }

  if price.nil? or volume.nil?
    return nil
  end

  account = my_chain_config["account"]
  #wallet_market_submit_ask <from_account_name> <sell_quantity> <sell_quantity_symbol> <ask_price> <ask_price_symbol> [allow_stupid_ask]
  response_json = chain_command command:"wallet_market_submit_ask", params:[account, volume, quote.upcase, price, base.upcase]

  if not response_json["error"].nil?
    $LOG.error (method(__method__).name) { JSON.pretty_generate response_json["error"] }
    return response_json["error"]
  else
    return response_json["result"]
  end

end


#main
if __FILE__ == $0

=begin
  if ARGV[0]
    ob = fetch_chain ARGV[0], ARGV[1]
  else
    ob = fetch_chain
  end
  print_order_book ob
=end

  if ARGV[0]
    if ARGV[1]
      args = ARGV.clone
      args.shift
      puts "command=" + ARGV[0]
      puts "args=" + args.to_s
      parsed_args = []
      args.each {|e|
        begin
          obj = JSON.parse e
          parsed_args.push obj
        rescue JSON::ParserError
          parsed_args.push e
        end
        
      }
      puts "parsed_args=" + parsed_args.to_s
      result = chain_command command:ARGV[0], params:parsed_args
    else
      result = chain_command command:ARGV[0], params:[]
    end
    begin
      puts JSON.pretty_generate result
    rescue
      puts result
    end
  else
    ob = fetch_chain
    print_order_book ob
    puts
    puts JSON.pretty_generate chain_balance
    puts chain_orders
  end

end
