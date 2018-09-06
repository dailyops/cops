app = lambda do |env| 
  body = ["Pong from #{`hostname`.chomp} at #{Time.now}!", 
          "version: v5", 
          "env:", 
          `env`.chomp].map{|l| "#{l}\n" }

  [200, {}, body] 
end
run app
