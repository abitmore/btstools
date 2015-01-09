#!/usr/bin/env ruby

####################################
# chain_test
#

require_relative "chain"

me = chain_balance
puts me

orders = chain_orders
puts orders
#orders = chain_orders type:"bid"

#puts chain_bid price:0.0013, volume:121.45
#puts chain_bid price:0.0014, volume:122.45
#puts chain_ask price:367.89, volume:0.2141
#puts chain_ask price:467.89, volume:0.2245
#puts chain_ask price:567.89, volume:0.2345
#puts chain_orders 

#if not orders["asks"].empty?
#  puts chain_cancel_order id:orders["asks"][0]["id"]
#end

o=[]
if not orders["asks"].empty?
  o.push( {"type"=>"cancel","id"=>orders["asks"][0]["id"]} )
end
if not orders["bids"].empty?
  o.push( {"type"=>"cancel","id"=>orders["bids"][0]["id"]} )
end
o.push( {"type"=>"bid","price"=>0.00567,"volume"=>1.9876} )
o.push( {"type"=>"ask","price"=>567.00567,"volume"=>12.3456} )
#puts o

#puts chain_submit_orders orders:o

#chain_cancel_order id:123

#puts chain_orders 

#resp = chain_cancel_order id:0, base:"cny"
#resp = chain_cancel_order id:40383019, base:"cny"
#puts resp.content

#chain_cancel_orders_by_type type:"bid"
#chain_cancel_orders_by_type type:"ask"
#chain_cancel_orders_by_type type:"all"
#chain_cancel_all_orders

#puts chain_orders
