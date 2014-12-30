#!/usr/bin/env ruby

require "httpclient"
require "json"

require_relative "myfunc"

####################################
# blockchain
#

# TODO write a class/function to communicate with rpc server

def fetch_chain (a1="bts",a2="cny",max_orders=5)
  #
  #client_public = HTTPClient.new nil, "curl/7.35.0", nil
  client_public = HTTPClient.new 
  client_public.connect_timeout=5
  client_public.receive_timeout=5
  
  uri='http://bts-wallet:9989/rpc'
  client_public.set_auth(uri,"test99","test9989")

  request_data= '{"jsonrpc": "2.0", "method": "blockchain_get_asset", "params":["'+a1.upcase+'"], "id":1}'
  response_content = client_public.post_content uri,request_data,nil
  response_json = JSON.parse response_content
  a1_precision = response_json["result"]["precision"]

  request_data= '{"jsonrpc": "2.0", "method": "blockchain_get_asset", "params":["'+a2.upcase+'"], "id":2}'
  response_content = client_public.post_content uri,request_data,nil
  response_json = JSON.parse response_content
  a2_precision = response_json["result"]["precision"]

  request_data= '{"jsonrpc": "2.0", "method": "blockchain_median_feed_price", "params":["'+a2.upcase+'"], "id":3}'
  response_content = client_public.post_content uri,request_data,nil
  response_json = JSON.parse response_content
  feed_price = response_json["result"]

  request_data= '{"jsonrpc": "2.0", "method": "blockchain_market_order_book", "params":["'+a2.upcase+'","'+a1.upcase+'"], "id":4}'
  #puts request_data
  order_book = client_public.post uri,request_data,nil
  #p order_book
  
  content = order_book.content
  #puts content
  ob = JSON.parse content
  #puts ob
  #puts JSON.pretty_generate ob["result"]
  
  #ask orders and cover orders are in same array. filter invalid short orders here
  asks = ob["result"][1].delete_if {|e| e["type"] == "cover_order" and
                                        e["market_index"]["order_price"]["ratio"].to_f*a1_precision/a2_precision < feed_price
                       }.sort_by {|e| e["market_index"]["order_price"]["ratio"].to_f}.first(max_orders)
  bids = ob["result"][0].sort_by {|e| e["market_index"]["order_price"]["ratio"].to_f}.reverse.first(max_orders)
  
  #asks_new=Hash[*asks.map["price","volume"]]
  asks_new=[]
  bids_new=[]
  asks.each do |e|
    item = {
      "price"=>e["market_index"]["order_price"]["ratio"].to_f*a1_precision/a2_precision,
      "volume"=>e["state"]["balance"].to_f/a2_precision
    }
    asks_new.push item
  end
  bids.each do |e|
    item = {
      "price"=>e["market_index"]["order_price"]["ratio"].to_f*a1_precision/a2_precision,
      "volume"=>e["state"]["balance"].to_f/a2_precision
    }
    bids_new.push item
  end
  
  #return
  ret={
    "source"=>"BLOCK CHAIN",
    "base"=>a2,
    "quote"=>a1,
    "asks"=>asks_new,
    "bids"=>bids_new
  }
  
end

#main
if __FILE__ == $0
  if ARGV[0]
    ob = fetch_chain ARGV[0], ARGV[1]
  else
    ob = fetch_chain
  end
  print_order_book ob
end
