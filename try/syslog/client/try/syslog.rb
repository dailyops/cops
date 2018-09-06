require 'byebug'
require 'syslog/logger'

# 注： 仅default名字起作用
l0 = Syslog::Logger.new('local0', Syslog::LOG_LOCAL0)
l1 = Syslog::Logger.new('local1', Syslog::LOG_LOCAL1)
l2 = Syslog::Logger.new('local2', Syslog::LOG_LOCAL2)
l3 = Syslog::Logger.new('local3', Syslog::LOG_LOCAL3)

puts '==try syslog here'
byebug

puts '==done'
