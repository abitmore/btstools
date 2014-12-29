#!/usr/bin/env ruby

require "active_support"
require 'peatio_client'

def fetch_yunbi

client_public = PeatioAPI::Client.new endpoint: 'https://yunbi.com'

#p client_public.get_public '/api/v2/markets'
#p client_public.get_public '/api/v2/tickers'
#p client_public.get_public '/api/v2/tickers/btsxcny'

order_book = client_public.get_public '/api/v2/order_book', {"market":"btsxcny", "asks_limit":10, "bids_limit":10}
ob = order_book

#parsed_order_book = JSON.parse ob
#pob = parsed_order_book

bids = ob["bids"].sort_by {|e| e["price"].to_f}.reverse
asks = ob["asks"].sort_by {|e| e["price"].to_f}.reverse

[asks,bids]

end

def print_yunbi
  ob = fetch_yunbi

  asks = ob[0]
  bids = ob[1]

  puts " asks "
  puts " price  remaining_volume "
    asks.each do |o|
    print o["price"], "\t", o["remaining_volume"]
    puts
  end

  puts " bids "
  puts " price  remaining_volume "
  bids.each do |o|
    print o["price"], "\t", o["remaining_volume"]
    puts
  end

end

#puts JSON.pretty_generate order_book

if __FILE__ == $0
  print_yunbi
end

