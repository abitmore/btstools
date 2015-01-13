#!/usr/bin/env ruby

puts "hello"

def h (a = "world")
    puts "hello #{a}"
    return a
end

bb=h "b"
puts bb


class P
  def initialize(name="world")
    @name=name;
  end
  def hi
    puts "hi #{@name}"
  end
  def hello
    puts "hello #{@name}"
  end
end

me = P.new("mm")
me.hi
me.hello

puts P.instance_methods(false)

class P
  attr_accessor :name
end

x=P.new("test")
puts x.name
x.hi
x.name ="new"
x.hello

obj = 'hello'
case obj  # was case obj.class
when String
  print('It is a string')
when Fixnum
  print('It is a number')
else
  print('It is not a string')
end
puts
