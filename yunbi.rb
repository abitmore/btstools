#!/usr/bin/env ruby

require "active_support"
require 'peatio_client'

require_relative "myfunc"

def fetch_yunbi (a1="bts",a2="cny",max_orders=5)
  
  client_public = PeatioAPI::Client.new endpoint: 'https://yunbi.com'
  
  #p client_public.get_public '/api/v2/markets'
  #p client_public.get_public '/api/v2/tickers'
  #p client_public.get_public '/api/v2/tickers/btsxcny'

  base = a2
  quote = (a1 == "bts" ? "btsx" : a1)
  market=quote+base
  
  order_book = client_public.get_public '/api/v2/order_book', {"market":market, "asks_limit":max_orders, "bids_limit":max_orders}
  ob = order_book
  
  #parsed_order_book = JSON.parse ob
  #pob = parsed_order_book
  
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
  ret={	\
    "source"=>"yunbi",	\
    "base"=>a2,		\
    "quote"=>a1,	\
    "asks"=>asks_new,	\
    "bids"=>bids_new	\
  }
   
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
