#!/usr/bin/env ruby

#GET
require 'net/http'

url = 'http://www.acme.com/products/3322' # ACME boomerang
resp = Net::HTTP.get_response(URI.parse(url))

resp_text = resp.body


#POST
require 'net/http'

url = 'http://www.acme.com/user/details'
params = {
  firstName => 'John',
  lastName => 'Doe'
}

resp = Net::HTTP.post_form(url, params)

resp_text = resp.body

