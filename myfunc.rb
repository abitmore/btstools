#!/usr/bin/env ruby

####################################
# functions
#

def print_order_book (ob)
  #ob = fetch_btc38 a1, a2
  src  = ob["source"]
  base = ob["base"]
  quot = ob["quote"]
  asks = ob["asks"]
  bids = ob["bids"]

  #puts JSON.pretty_generate order_book

  puts " SOURCE: "+src
  puts " MARKET: "+quot+"/"+base

  puts
  puts " asks"
  puts "price   volume "
    asks.reverse.each do |o|
    print ("%.12f" % o["price"]).sub(/0*$/,"").sub(/\.$/,""), "\t", ("%.8f" % o["volume"]).sub(/0*$/,"").sub(/\.$/,"")
    puts
  end

  puts
  puts " bids"
  puts "price   volume "
  bids.each do |o|
    print ("%.12f" % o["price"]).sub(/0*$/,"").sub(/\.$/,""), "\t", ("%.8f" % o["volume"]).sub(/0*$/,"").sub(/\.$/,"")
    puts
  end

end

if __FILE__ == $0
  test_order_book = {	\
    "source"=>"test_source",	\
    "base"=>"cny",	\
    "quote"=>"test",	\
    "asks"=>[{"price"=>1.1,"volume"=>100},{"price"=>2.2,"volume"=>0.1}],	\
    "bids"=>[{"price"=>0.09,"volume"=>30000},{"price"=>0.0055,"volume"=>99999999},{"price"=>0.00003,"volume"=>274398274389},{"price"=>0.0000001,"volume"=>12342432.21341242}]	\
  }
  print_order_book test_order_book
end

