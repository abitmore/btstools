#!/usr/bin/env ruby

require 'bigdecimal'

require_relative "chain.rb"

####################################
# a bot for btsbots.exch
#

$loop_bts = 16000
$loop_cny = 1000
$loop_price = 0.0625

$acc0 = "fund_from_and_to"
$acc_auction = "auction.btsbots"

$acc_prefix = "testname"
$acc_used = 2
$acc_end = 2
$acc1 = "testname001"
$acc2 = "testname002"

def init_acc
  puts $My_exch_bot_config
  $acc0 = $My_exch_bot_config["acc0"]
  $acc_prefix = $My_exch_bot_config["acc_prefix"]
  $acc_used = $My_exch_bot_config["acc_used_seq"] - 2
  $acc_end = $My_exch_bot_config["acc_end_seq"]
  $acc1 = next_acc
  $acc2 = next_acc
end

def next_acc
  acc_name = $acc_prefix + ("%03d" % ($acc_used+1))
  $acc_used += 1
  return acc_name
end

# wrapper of to_f
def my_f (o)
  begin
    return o.to_f
  rescue Exception => e
    return 0.0
  end
end

# get balance from bal
def my_bal (bal, currency)
  begin
    return my_f bal[currency]
  rescue Exception => e
    return 0.0
  end
end

# replace of Float.-
def subf (a,b)
  a1=BigDecimal.new(a.to_s)
  b1=BigDecimal.new(b.to_s)
  return (a1-b1).to_f
end

# one loop
def exchbot ()

  acc1_fee_need = 0.3
  acc2_fee_need = 0.4

  #acc1_bts_balance = get bts balance of acc1
  acc1_bals = chain_balance account:$acc1
  acc1_bts_balance = my_bal acc1_bals, "bts"
  acc1_bts_need = subf $loop_bts + acc1_fee_need , acc1_bts_balance
  printf "acc1 bts: %f need: %f \n", acc1_bts_balance, acc1_bts_need

  #acc2_bts_balance = get bts balance of acc2
  #acc2_bts_need = acc2_fee_need - acc2_bts_balance
  acc2_bals = chain_balance account:$acc2
  acc2_bts_balance = my_bal acc2_bals, "bts"
  acc2_bts_need = subf acc2_fee_need , acc2_bts_balance
  printf "acc2 bts: %f need: %f \n", acc2_bts_balance, acc2_bts_need

  #acc2_cny_balance = get botscny balance of acc2
  #acc2_cny_need = loop_cny - acc2_cny_balance
  acc2_cny_balance = my_bal acc2_bals, "botscny"
  acc2_cny_need = subf $loop_cny , acc2_cny_balance
  printf "acc2 botscny: %f need: %f \n", acc2_cny_balance, acc2_cny_need

  #check balance of acc0
  acc0_bals = chain_balance account:$acc0
  acc0_bts_balance = my_bal acc0_bals, "bts"
  acc0_cny_balance = my_bal acc0_bals, "cny"
  acc0_botscny_balance = my_bal acc0_bals, "botscny"
  if acc0_bts_balance < 0.4 + acc1_bts_need + acc2_bts_need
    $LOG.error "no enough bts"
    exit
  end
  if acc0_cny_balance + acc0_botscny_balance < acc2_cny_need
    $LOG.error "no enough cny"
    exit
  end

  need_wait = false
  #transfer (acc1_bts_need) bts from acc0 to acc1 (for fee, and the amount less)
  if acc1_bts_need > 0
    need_wait = true
    r = chain_command command:"transfer", params:[acc1_bts_need,"BTS",$acc0,$acc1]
    if r["error"]
      $LOG.error ("transfer_bts_acc0_acc1") { JSON.pretty_generate r }
      exit
    end
  end
  #transfer (acc2_bts_need) bts from acc0 to acc2 (for fee)
  if acc2_bts_need > 0
    need_wait = true
    r = chain_command command:"transfer", params:[acc2_bts_need,"BTS",$acc0,$acc2]
    if r["error"]
      $LOG.error ("transfer_bts_acc0_acc2") { JSON.pretty_generate r }
      exit
    end
  end
  #transfer (acc2_cny_need) cny from acc0 to acc2 (for amount less)
  if acc2_cny_need > 0
    need_wait = true
    if acc0_botscny_balance >= acc2_cny_need
      r = chain_command command:"transfer", params:[acc2_cny_need,"BOTSCNY",$acc0,$acc2]
      if r["error"]
        $LOG.error ("transfer_botscny_acc0_acc2") { JSON.pretty_generate r }
        exit
      end
    elsif acc0_cny_balance >= acc2_cny_need
      r = chain_command command:"transfer", params:[acc2_cny_need,"CNY",$acc0,$acc2]
      if r["error"]
        $LOG.error ("transfer_cny_acc0_acc2") { JSON.pretty_generate r }
        exit
      end
    else
      $LOG.error "no enough cny"
      exit
    end
  end

  # wait until transfer complete
  if need_wait
    while true
      chain_command command:"wait_for_block_by_number", params:[2,"relative"], timeout:55

      # re-check balance of acc2
      acc1_bals = chain_balance account:$acc1
      acc2_bals = chain_balance account:$acc2

      acc1_bts_balance = my_bal acc1_bals, "bts"
      acc2_cny_balance = my_bal acc2_bals, "cny"
      acc2_botscny_balance = my_bal acc2_bals, "botscny"

      if acc1_bts_balance == $loop_bts + acc1_fee_need and acc2_cny_balance + acc2_botscny_balance == $loop_cny
        break
      end
    end
  end

  # re-check balance of acc2
  acc1_bals = chain_balance account:$acc1
  acc2_bals = chain_balance account:$acc2
  acc2_cny_balance = my_bal acc2_bals, "cny"
  acc2_botscny_balance = my_bal acc2_bals, "botscny"

  puts "After adjust:"
  puts JSON.pretty_generate acc1_bals
  puts JSON.pretty_generate acc2_bals

  #transfer (loop_bts) bts from acc1 to auction.btsbots
  r = chain_command command:"transfer", params:[$loop_bts,"BTS",$acc1,$acc_auction,$loop_price]
  if r["error"]
    $LOG.error ("transfer_bts_acc1_auction") { JSON.pretty_generate r }
    exit
  end
  #transfer (acc2_botscny_balance) botscny from acc2 to auction.btsbots
  if acc2_botscny_balance > 0
    r = chain_command command:"transfer", params:[acc2_botscny_balance,"BOTSCNY",$acc2,$acc_auction,$loop_price]
    if r["error"]
      $LOG.error ("transfer_botscny_acc2_auction") { JSON.pretty_generate r }
      exit
    end
  end
  #transfer (acc2_cny_balance) cny from acc2 to auction.btsbots
  if acc2_cny_balance > 0
    r = chain_command command:"transfer", params:[acc2_cny_balance,"CNY",$acc2,$acc_auction,$loop_price]
    if r["error"]
      $LOG.error ("transfer_cny_acc2_auction") { JSON.pretty_generate r }
      exit
    end
  end

  # wait until btsbots execute
  while true
    acc1_bals = chain_balance account:$acc1
    acc1_botscny_balance = my_bal acc1_bals, "botscny"
    acc2_bals = chain_balance account:$acc2
    acc2_bts_balance = my_bal acc2_bals, "bts"
    if acc1_botscny_balance > 0 and acc2_bts_balance > 1
      # acc1 now has btsbots.exch and botscny
      # acc2 now has btsbots.exch and bts
      chain_command command:"wait_for_block_by_number", params:[2,"relative"], timeout:55
      break
    end
    r = chain_command command:"blockchain_get_block_count", params:[]
    printf "Current block=%d, wait for 2 blocks\n", r["result"]
    chain_command command:"wait_for_block_by_number", params:[2,"relative"], timeout:55
  end

  acc1_bals = chain_balance account:$acc1
  acc2_bals = chain_balance account:$acc2
  # acc1 now has btsbots.exch and botscny
  # acc2 now has btsbots.exch and bts
  begin
    puts "After trade:"
    puts JSON.pretty_generate acc1_bals
    puts JSON.pretty_generate acc2_bals
  rescue
  end


  #acc1_exch_balance = get btsbots.exch balance from acc1
  acc1_exch_balance = my_bal acc1_bals, "btsbots.exch"
  #acc2_exch_balance = get btsbots.exch balance from acc2
  acc2_exch_balance = my_bal acc2_bals, "btsbots.exch"

  #transfer (acc1_exch_balance) btsbots.exch from acc1 to acc0
  if acc1_exch_balance > 0
    r = chain_command command:"transfer", params:[acc1_exch_balance,"BTSBOTS.EXCH",$acc1,$acc0]
    if r["error"]
      $LOG.error ("transfer_exch_acc1_acc0") { JSON.pretty_generate r }
    end
  end
  #transfer (acc2_exch_balance) btsbots.exch from acc2 to acc0
  acc2_fee = 0
  if acc2_exch_balance > 0
    acc2_fee = 0.1
    r = chain_command command:"transfer", params:[acc2_exch_balance,"BTSBOTS.EXCH",$acc2,$acc0]
    if r["error"]
      $LOG.error ("transfer_exch_acc2_acc0") { JSON.pretty_generate r }
    end
  end

  #acc3 = next send bts account
  acc3 = next_acc
  #acc4 = next send cny account
  acc4 = next_acc
  printf "acc3=%s acc4=%s\n",acc3,acc4

  #acc1_botscny_balance = get botscny balance from acc1
  acc1_botscny_balance = my_bal acc1_bals, "botscny"
  #acc2_bts_balance = get bts balance from acc2
  acc2_bts_balance = my_bal acc2_bals, "bts"

  #transfer (acc2_bts_balance-0.1) bts from acc2 to acc3
  if acc2_bts_balance > 0.1 + acc2_fee
    transfer_amt = subf acc2_bts_balance, 0.1+acc2_fee
    r = chain_command command:"transfer", params:[transfer_amt,"BTS",$acc2,acc3]
    if r["error"]
      $LOG.error ("transfer_bts_acc2_acc3") { JSON.pretty_generate r }
      exit
    end
  end
  #transfer (acc1_cny_balance) botscny from acc1 to acc4
  if acc1_botscny_balance > 0
    r = chain_command command:"transfer", params:[acc1_botscny_balance,"BOTSCNY",$acc1,acc4]
    if r["error"]
      $LOG.error ("transfer_botscny_acc1_acc4") { JSON.pretty_generate r }
      exit
    end
  end

  $acc1 = acc3
  $acc2 = acc4

  # wait for 2 blocks
  chain_command command:"wait_for_block_by_number", params:[2,"relative"], timeout:55

end


#main
if __FILE__ == $0

  init_acc
  while $acc_used < $acc_end
    printf "acc1=%s acc2=%s\n",$acc1,$acc2
    exchbot
  end

end
