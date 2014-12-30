#curl -v --data '{"jsonrpc": "2.0", "method": "get_info", "params": [], "id": 1}' http://test99:test9989@localhost:9989/rpc;echo
#curl -v -d '{"jsonrpc": "2.0", "method": "blockchain_get_asset", "params":["CNY"], "id":2}' http://test99:test9989@localhost:9989/rpc;echo
curl -v -d '{"jsonrpc": "2.0", "method": "blockchain_median_feed_price", "params":["CNY"], "id":2}' http://test99:test9989@localhost:9989/rpc;echo
