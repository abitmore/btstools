#!/usr/bin/env ruby

####################################
# yunbi_test
#

require_relative "yunbi"

#me = mybalance_yunbi
#puts me

#orders = yunbi_orders type:"bid"
#puts orders
#
puts yunbi_bid price:0.0013, volume:121.45
puts yunbi_bid price:0.0014, volume:122.45
puts yunbi_ask price:367.89, volume:0.2141
puts yunbi_ask price:467.89, volume:0.2245
puts yunbi_ask price:567.89, volume:0.2345
puts yunbi_orders 

#yunbi_cancel_orders_by_type type:"bid"
#yunbi_cancel_orders_by_type type:"ask"
yunbi_cancel_orders_by_type type:"all"
#yunbi_cancel_all_orders

puts yunbi_orders 
