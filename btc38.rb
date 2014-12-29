#!/usr/bin/env ruby

require "httpclient"
require "json"

def fetch_btc38
#http://api.btc38.com/v1/depth.php?c=ltc&mk_type=cny
#client_public = HTTPClient.new nil, "curl/7.35.0", nil
client_public = HTTPClient.new 
client_public.connect_timeout=5
client_public.receive_timeout=5

uri='http://api.btc38.com/v1/depth.php?c=bts&mk_type=cny'
order_book = client_public.get uri,nil,{"User-Agent":"curl/7.35.0","Accept":"*/*"}
#puts order_book
#puts JSON.pretty_generate order_book

content = order_book.content
#puts content
ob = JSON.parse content
#puts ob

#parsed_order_book = JSON.parse ob
#pob = parsed_order_book

asks = ob["asks"].sort_by {|e| e[0].to_f}.reverse.last(10)
bids = ob["bids"].sort_by {|e| e[0].to_f}.reverse.first(10)

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

#puts asks_new
#puts bids_new

#[asks,bids]
[asks_new,bids_new]

end

def print_btc38
  ob = fetch_btc38
  asks = ob[0]
  bids = ob[1]

  puts " asks "
  puts " price  remaining_volume "
    asks.each do |o|
    #print o[0], "\t", o[1]
    print o["price"], "\t", o["volume"]
    puts
  end

  puts " bids "
  puts " price  remaining_volume "
  bids.each do |o|
    #print o[0], "\t", o[1]
    print o["price"], "\t", o["volume"]
    puts
  end

end

if __FILE__ == $0
  print_btc38
end
