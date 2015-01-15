#!/usr/bin/env ruby

require "httpclient"
require "json"
require "digest"

require_relative "myfunc"
require_relative "config"
require_relative "mylogger"

####################################
# btc38 data update every 15 seconds
#

def new_btc38_client
  client = HTTPClient.new
  client.connect_timeout=5
  client.receive_timeout=5
  return client
end

def btc38_get (uri:nil)
  if uri.nil?
    return
  end
  client = new_btc38_client
  begin
    return client.get uri, nil, {"User-Agent":"curl/7.35.0","Accept":"*/*"}
  rescue Exception => e
    print "btc38_get error: "
    puts e
  end
end

def btc38_post (uri:nil, data:{})
  if uri.nil?
    return
  end
  client = new_btc38_client
  begin
    return client.post uri, data, {"User-Agent":"curl/7.35.0","Accept":"*/*"}
  rescue Exception => e
    print "btc38_post error: "
    puts e
  end
end

def fetch_btc38 (quote="bts", base="cny", max_orders=5)
  btc38_fetch quote:quote, base:base, max_orders:max_orders
end

def btc38_fetch (quote:"bts", base:"cny", max_orders:5)
  #http://api.btc38.com/v1/depth.php?c=ltc&mk_type=cny
  uri='http://api.btc38.com/v1/depth.php?c='+quote+'&mk_type='+base
  resp = btc38_get uri:uri
  #puts resp
  #puts JSON.pretty_generate resp
  if resp.nil?
    return {
      "source"=>"btc38",
      "base"=>base,
      "quote"=>quote,
      "asks"=>[],
      "bids"=>[]
    }
  end
  
  content = resp.content
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
  ret={
    "source"=>"btc38",
    "base"=>base,
    "quote"=>quote,
    "asks"=>asks_new,
    "bids"=>bids_new
  }
  
end

def btc38_balance
  #http://www.btc38.com/trade/t_api/getMyBalance.php
  uri = 'http://www.btc38.com/trade/t_api/getMyBalance.php'
  now_seconds = Time.now.to_i
  #md5(key_userID_skey_time)
  now_md5 = Digest::MD5.hexdigest my_btc38_public_key + '_' + my_btc38_id + '_' + my_btc38_private_key + '_' + now_seconds.to_s
  data = {
    "key"  => my_btc38_public_key,
    "time" => now_seconds,
    "md5"  => now_md5
  }
  resp = btc38_post uri:uri, data:data
  #puts resp
  #puts JSON.pretty_generate resp
  if resp.nil?
    return { }
  end

  content = resp.content.force_encoding("UTF-8")
  # remove UTF-8 BOM
  content.sub!(/^\xEF\xBB\xBF/,'')

  balances = JSON.parse (content)
  #puts balances

  my_balance=Hash.new
  currencies = ["cny", "bts", "btc"]
  #currencies.each { |e| my_balance.store e, balances[e+"_balance"].to_f - balances[e+"_balance_lock"].to_f }
  currencies.each { |e| my_balance.store e, balances[e+"_balance"].to_f }

  return my_balance

end

def btc38_orders (quote:"bts", base:"cny", type:"all")
  ret = {
      "source"=>"btc38",
      "base"=>base,
      "quote"=>quote,
      "asks"=>[],
      "bids"=>[]
  }
  if "cny" != base and "btc" != base
    return ret
  end

  #http://www.btc38.com/trade/t_api/getOrderList.php
  uri = 'http://www.btc38.com/trade/t_api/getOrderList.php'
  now_seconds = Time.now.to_i
  #md5(key_userID_skey_time)
  now_md5 = Digest::MD5.hexdigest my_btc38_public_key + '_' + my_btc38_id + '_' + my_btc38_private_key + '_' + now_seconds.to_s
  data = {
    "key"  => my_btc38_public_key,
    "time" => now_seconds,
    "md5"  => now_md5
  }
  data["mk_type"] = base
  data["coinname"] = quote
  resp = btc38_post uri:uri, data:data
  #puts resp
  #puts JSON.pretty_generate resp
  if resp.nil?
    return ret
  end

  content = resp.content.force_encoding("UTF-8")
  # remove UTF-8 BOM
  content.sub!(/^\xEF\xBB\xBF/,'')
  #puts content
  if "no_order" == content
    return ret
   end

  orders = JSON.parse (content)
  #puts orders

  need_ask = ("all" == type or "ask" == type)
  need_bid = ("all" == type or "bid" == type)
  asks_new=[]
  bids_new=[]
  orders.each do |e|
    if "1" == e["type"] and need_bid
      item = {"id"=>e["id"],"price"=>e["price"],"volume"=>e["amount"]}
      bids_new.push item
    elsif "2" == e["type"] and need_ask
      item = {"id"=>e["id"],"price"=>e["price"],"volume"=>e["amount"]}
      asks_new.push item
    end
  end

  asks_new.sort_by! {|e| e["price"].to_f}
  bids_new.sort_by! {|e| e["price"].to_f}.reverse!

  ret["asks"]=asks_new
  ret["bids"]=bids_new

  return ret

end

def btc38_cancel_order (id:0, base:"cny")
  if 0 == id
    return
  end
  if "cny" != base and "btc" != base
    return
  end
  #http://www.btc38.com/trade/t_api/cancelOrder.php
  uri = 'http://www.btc38.com/trade/t_api/cancelOrder.php'
  now_seconds = Time.now.to_i
  #md5(key_userID_skey_time)
  now_md5 = Digest::MD5.hexdigest my_btc38_public_key + '_' + my_btc38_id + '_' + my_btc38_private_key + '_' + now_seconds.to_s
  data = {
    "key"  => my_btc38_public_key,
    "time" => now_seconds,
    "md5"  => now_md5
  }
  data["mk_type"] = base
  data["order_id"] = id
  #puts data
  resp = btc38_post uri:uri, data:data
  if not resp.nil?
    content = resp.content.force_encoding("UTF-8")
    # remove UTF-8 BOM
    content.sub!(/^\xEF\xBB\xBF/,'')
    $LOG.debug (method(__method__).name) { {"return"=>content } }
    return content
  else
    $LOG.debug (method(__method__).name) { {"return"=>nil } }
    return ""
  end
end

def btc38_cancel_orders (ids:[], base:"cny")
  ids.each { |id| btc38_cancel_order id:id, base:base }
end

def btc38_cancel_orders_by_type (quote:"bts", base:"cny", type:"all")
  orders = btc38_orders quote:quote, base:base, type:type
  orders["asks"].each {|e| btc38_cancel_order id:e["id"], base:base}
  orders["bids"].each {|e| brc38_cancel_order id:e["id"], base:base}
end

def btc38_cancel_all_orders (quote:"bts", base:"cny")
  btc38_cancel_orders_by_type quote:quote, base:base, type:"all"
end

def btc38_new_order (quote:"bts", base:"cny", type:nil, price:nil, volume:nil)
  $LOG.info (method(__method__).name) { {"parameters"=>method(__method__).parameters.map { |arg| "#{arg[1]} = #{eval arg[1].to_s}" }.join(', ') } }
  if type.nil? or price.nil? or volume.nil?
    return false
  end
  if "cny" != base and "btc" != base
    return false
  end

  #http://www.btc38.com/trade/t_api/submitOrder.php
  uri = 'http://www.btc38.com/trade/t_api/submitOrder.php'
  now_seconds = Time.now.to_i
  #md5(key_userID_skey_time)
  now_md5 = Digest::MD5.hexdigest my_btc38_public_key + '_' + my_btc38_id + '_' + my_btc38_private_key + '_' + now_seconds.to_s
  data = {
    "key"  => my_btc38_public_key,
    "time" => now_seconds,
    "md5"  => now_md5
  }
  data["type"] = ("bid" == type ? "1" : "2")
  data["mk_type"] = base
  data["price"] = price
  data["amount"] = ("%.6f" % volume.to_f)  # up to 6 decimal digits
  data["coinname"] = quote
  resp = btc38_post uri:uri, data:data
  #puts resp
  #puts JSON.pretty_generate resp
  if resp.nil?
    return ""
  end

  content = resp.content.force_encoding("UTF-8")
  # remove UTF-8 BOM
  content.sub!(/^\xEF\xBB\xBF/,'')
  $LOG.debug (method(__method__).name) { {"return"=>content } }
  #puts content
  return content

end

def btc38_bid (quote:"bts", base:"cny", price:nil, volume:nil)
  btc38_new_order quote:quote, base:base, type:"bid", price:price, volume:volume
end

def btc38_ask (quote:"bts", base:"cny", price:nil, volume:nil)
  btc38_new_order quote:quote, base:base, type:"ask", price:price, volume:volume
end

def btc38_submit_orders (orders:nil, quote:"bts", base:"cny")
  $LOG.info (method(__method__).name) { {"parameters"=>method(__method__).parameters.map { |arg| "#{arg[1]} = #{eval arg[1].to_s}" }.join(', ') } }

  return nil if orders.nil? or orders.empty?

  orders.each { |e|
    case e["type"]
    when "cancel"
      btc38_cancel_order id:e["id"], base:base
    when "ask", "bid"
      btc38_new_order quote:(e["quote"] or quote), base:(e["base"] or base), type:e["type"], price:e["price"], volume:e["volume"]
    end
  }

end


#main
if __FILE__ == $0
  if ARGV[0]
    ob = fetch_btc38 ARGV[0], ARGV[1]
  else
    ob = fetch_btc38
  end
  print_order_book ob
  puts
  puts JSON.pretty_generate btc38_balance
  puts btc38_orders
end
