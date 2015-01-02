#!/usr/bin/env ruby

require "active_support"
require 'peatio_client'

require_relative "config"
require_relative "myfunc"

def new_yunbi_client
  client = PeatioAPI::Client.new endpoint: 'https://yunbi.com', access_key: my_yunbi_access_key, secret_key: my_yunbi_secret_key
end

def new_yunbi_pub_client
  client_public = PeatioAPI::Client.new endpoint: 'https://yunbi.com'
end

def fetch_yunbi (quote="bts", base="cny", max_orders=5)
  yunbi_fetch quote:quote, base:base, max_orders:max_orders
end

def yunbi_fetch (quote:"bts", base:"cny", max_orders:5)
  
  client_public = new_yunbi_pub_client
  
  new_quote = (quote == "bts" ? "btsx" : quote)
  market = new_quote + base
  
  order_book = client_public.get_public '/api/v2/order_book', {"market":market, "asks_limit":max_orders, "bids_limit":max_orders}
  ob = order_book
  
  asks = ob["asks"].sort_by {|e| e["price"].to_f}
  bids = ob["bids"].sort_by {|e| e["price"].to_f}.reverse
  
  asks_new=[]
  bids_new=[]
  asks.each do |e|
    item = {"price"=>e["price"],"volume"=>e["remaining_volume"]}
    asks_new.push item
  end
  bids.each do |e|
    item = {"price"=>e["price"],"volume"=>e["remaining_volume"]}
    bids_new.push item
  end

  #return
  {
    "source"=>"yunbi",
    "base"=>base,
    "quote"=>quote,
    "asks"=>asks_new,
    "bids"=>bids_new
  }
   
end

def yunbi_balance
  client = new_yunbi_client
  
  me = client.get '/api/v2/members/me'

  my_accounts = me["accounts"]

  my_balance=Hash.new
  my_accounts.each { |e| my_balance.store e["currency"],e["balance"].to_f - e["locked"].to_f }

  if my_balance["bts"].nil?
    my_balance.store "bts", my_balance["btsx"]
  end

  return my_balance

end

#for test
#def orders_yunbi (options={})
  #default_options = {:base=>"cny", :quote=>"bts", :type=>"all"}
  #options = default_options.merge options
#end

def yunbi_orders (quote:"bts", base:"cny", type:"all")

  client = new_yunbi_client
  
  new_quote = (quote == "bts" ? "btsx" : quote)
  market = new_quote + base

  orders = client.get '/api/v2/orders', {"market":market}

  need_ask = ("all" == type or "ask" == type)
  need_bid = ("all" == type or "bid" == type)
  asks_new=[]
  bids_new=[]
  orders.each do |e|
    if "buy" == e["side"] and need_bid
      item = {"id"=>e["id"],"price"=>e["price"],"volume"=>e["remaining_volume"]}
      bids_new.push item
    elsif "sell" == e["side"] and need_ask
      item = {"id"=>e["id"],"price"=>e["price"],"volume"=>e["remaining_volume"]}
      asks_new.push item
    end
  end

  asks_new.sort_by! {|e| e["price"].to_f}
  bids_new.sort_by! {|e| e["price"].to_f}.reverse!

  #return
  {
    "source"=>"yunbi",
    "base"=>base,	
    "quote"=>quote,
    "asks"=>asks_new,
    "bids"=>bids_new
  }
 
end

def yunbi_cancel_order (id)
  client = new_yunbi_client
  client.post '/api/v2/order/delete', {"id":id}
end

def yunbi_cancel_orders (ids)
  client = new_yunbi_client
  ids.each { |id| client.post '/api/v2/order/delete', {"id":id} }
end

def yunbi_cancel_orders_by_type (quote:"bts", base:"cny", type:"all")
  orders = yunbi_orders quote:quote, base:base, type:type
  orders["asks"].each {|e| yunbi_cancel_order e["id"]}
  orders["bids"].each {|e| yunbi_cancel_order e["id"]}
end

def yunbi_cancel_all_orders
  client = new_yunbi_client
  orders = client.post '/api/v2/orders/clear'
end

def yunbi_new_order (quote:"bts", base:"cny", type:nil, price:nil, volume:nil)
  if type.nil? or price.nil? or volume.nil?
    return
  end

  new_quote = (quote == "bts" ? "btsx" : quote)
  market = new_quote + base

  new_type = ((type == "bid" or type == "buy") ? "buy" : "sell")

  client = new_yunbi_client
  orders = client.post '/api/v2/orders', {"market":market, "side":new_type, "price":price, "volume":volume}

end

def yunbi_bid (quote:"bts", base:"cny", price:nil, volume:nil)
  yunbi_new_order quote:quote, base:base, type:"bid", price:price, volume:volume
end

def yunbi_ask (quote:"bts", base:"cny", price:nil, volume:nil)
  yunbi_new_order quote:quote, base:base, type:"ask", price:price, volume:volume
end

#main
if __FILE__ == $0
  if ARGV[0]
    ob = fetch_yunbi ARGV[0], ARGV[1]
  else
    ob = fetch_yunbi
  end
  print_order_book ob
end
