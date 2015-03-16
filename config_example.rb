#!/usr/bin/env ruby

####################################
# config
#

$MY_TRADE_CONFIG = {
  "min_profit_margin" => 0.005
}

$MY_TRADE_ORDER = {
  "yunbi" => 1,
  "btc38" => 2,
  "chain" => 9
}

# if balance of an account < min_balance, ignore this account
$MY_ACCOUNT_CONFIG = {
  "cny" => {
    "min_order" => 10,
    "min_balance" => 10
  },
  "usd" => {
    "min_order" => 1,
    "min_balance" => 1
  },
  "bts" => {
    "min_order" => 100,
    "min_balance" => 100
  },
  "btc" => {
    "min_order" => 0.01,
    "min_balance" => 0.01
  }
}

# config for exchbot
$My_exch_bot_config = {
  "acc0" => "the_account_which_fund_from_and_to",
  "acc_prefix" => "bot_",
  "acc_used_seq" => 2,
  "acc_end_seq" => 100
}

def my_chain_config
  {
    "uri"  => 'http://bts-wallet:9989/rpc',
    "user" => 'test',
    "pass" => 'test',
    "account" => 'test_account'
  }
end

def my_compare_markets
# remarks: 
# 0. the order of markets is about order while fetching
# 1. price of yunbi is more sensitive than btc38 (spread is much smaller)
# 2. response of chain is fastest
  ["btc38", "yunbi", "chain"]
#  ["yunbi", "btc38"]
end

def my_yunbi_access_key 
  "my_yunbi_access_key" 
end
def my_yunbi_secret_key 
  "my_yunbi_secret_key" 
end

def my_btc38_id
  "123456789" 
end
def my_btc38_public_key 
  "my_btc38_public_key" 
end
def my_btc38_private_key 
  "my_btc38_private_key" 
end


