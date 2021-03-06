#!/usr/bin/env ruby

require "httpclient"
require "json"

require_relative "myfunc"

####################################
# bter
#

def fetch_bter (a1="bts",a2="cny",max_orders=5)
  #http://data.bter.com/api/1/depth/[CURR_A]_[CURR_B]
  #client_public = HTTPClient.new nil, "curl/7.35.0", nil
  client_public = HTTPClient.new 
  client_public.connect_timeout=5
  client_public.receive_timeout=5
  
  uri='http://data.bter.com/api/1/depth/'+a1+'_'+a2
  order_book = client_public.get uri,nil,{"User-Agent":"curl/7.35.0","Accept":"*/*"}
  #puts order_book
  #puts JSON.pretty_generate order_book
  
  content = order_book.content
  #puts content
  ob = JSON.parse content
  #puts ob
  
  asks = ob["asks"].sort_by {|e| e[0].to_f}.first(max_orders)
  bids = ob["bids"].sort_by {|e| e[0].to_f}.reverse.first(max_orders)
  
  #asks_new=Hash[*asks.map["price","volume"]]
  asks_new=[]
  bids_new=[]
  asks.each do |e|
    item = {"price"=>e[0],"volume"=>e[1]}
    asks_new.push item
  end
  bids.each do |e|
    item = {"price"=>e[0],"volume"=>e[1]}
    bids_new.push item
  end
  
  #return
  ret={	\
    "source"=>"bter",	\
    "base"=>a2,		\
    "quote"=>a1,	\
    "asks"=>asks_new,	\
    "bids"=>bids_new	\
  }
  
end

#main
if __FILE__ == $0
  if ARGV[0]
    ob = fetch_bter ARGV[0], ARGV[1]
  else
    ob = fetch_bter
  end
  print_order_book ob
end
