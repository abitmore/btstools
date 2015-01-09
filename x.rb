#!/usr/bin/env ruby

i=1
while i <= 9 
  j=1
  s=""
  while j <= i 
    s = s + j.to_s + "*" + i.to_s + "=" + (i*j).to_s  + " "
    j += 1
  end
  puts s
  i += 1
end

for i in 1 .. 9
  for j in 1 .. i
    print j, '*', i, '=', j*i, ' '
  end
  puts
end
