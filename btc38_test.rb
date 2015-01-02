#!/usr/bin/env ruby

####################################
# btc38_test
#

require_relative "btc38"

#me = btc38_balance
#puts me

puts btc38_orders
#orders = btc38_orders type:"bid"

#puts btc38_bid price:0.0013, volume:121.45
#puts btc38_bid price:0.0014, volume:122.45
puts btc38_ask price:367.89, volume:0.2141
puts btc38_ask price:467.89, volume:0.2245
puts btc38_ask price:567.89, volume:0.2345
puts btc38_orders 

#resp = btc38_cancel_order id:0, base:"cny"
#resp = btc38_cancel_order id:40383019, base:"cny"
#puts resp.content

#btc38_cancel_orders_by_type type:"bid"
#btc38_cancel_orders_by_type type:"ask"
#btc38_cancel_orders_by_type type:"all"
btc38_cancel_all_orders

puts btc38_orders
