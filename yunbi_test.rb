#!/usr/bin/env ruby

####################################
# yunbi_test
#

require_relative "yunbi"

me = yunbi_balance
puts me

#orders = yunbi_orders type:"bid"
orders = yunbi_orders type:"all"
puts orders
#
#puts yunbi_bid price:0.0013, volume:121.45
#puts yunbi_bid price:0.0014, volume:122.45
#puts yunbi_ask price:367.89, volume:0.2141
#puts yunbi_ask price:467.89, volume:0.2245
#puts yunbi_ask price:567.89, volume:0.2345
#puts yunbi_orders 
=begin
o=[]
if not orders["asks"].empty?
  o.push( {"type"=>"cancel","id"=>orders["asks"][0]["id"]} )
end
if not orders["bids"].empty?
  o.push( {"type"=>"cancel","id"=>orders["bids"][0]["id"]} )
end
o.push( {"type"=>"bid","price"=>0.00567,"volume"=>1341.9876} )
o.push( {"type"=>"ask","price"=>567.00567,"volume"=>12.3456} )
o.push( {"type"=>"ask","price"=>1567.00567,"volume"=>2.3456} )
puts o

response = yunbi_submit_orders orders:o
puts response
=end

#puts yunbi_orders 

#yunbi_cancel_orders_by_type type:"bid"
#yunbi_cancel_orders_by_type type:"ask"
#yunbi_cancel_orders_by_type type:"all"
#yunbi_cancel_all_orders

#puts yunbi_orders 
