#!/usr/bin/env ruby

require "json"

#JSON.parse(string, symbolize_names: true) #=> {key: :value}

string = '{"desc":{"someKey":"someValue","anotherKey":"value"},"main_item":{"stats":{"a":8,"b":12,"c":10}}}'
parsed = JSON.parse(string) # returns a hash

p parsed["desc"]["someKey"]
p parsed["main_item"]["stats"]["a"]

# Read JSON from a file, iterate over objects
file = open("shops.json")
json = file.read

parsed = JSON.parse(json)

parsed["shop"].each do |shop|
  p shop["id"]
end

