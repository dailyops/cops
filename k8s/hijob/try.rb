#!/usr/bin/env ruby

a = rand
puts "random a=#{a}"
if a < 0.5
  puts "hit fail"
  exit 3
else
  puts rand(999 ** 99)
end
puts "complete ok..."
