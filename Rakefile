namespace :dklet do
  desc 'hi to dklet'
  task :hi do
    hipath = 'tmp/hidklet'
    result = system <<~Desc
      rm -f #{hipath}
      mkdklet #{hipath}
      #{hipath} help
      #{hipath} # main task
      #{hipath} clean
    Desc

    if result
      puts 'everything ok' 
    else
      puts 'something wrong' 
    end
  end

  desc 'batch test'
  task :test do
    system <<~Desc
      dklet/try main
      dklet/try clean
      pg/dklet main
      pg/dklet clean
    Desc
  end
end

task default: ['dklet:test']

task :devdns do
  script = 'local/devdns/dklet'
  if File.exists?(script)
    system script
    puts "==run #{script}"
  else
    puts "not found #{script}"
  end
end

# todo prod-net 
task :dailyops do
  system <<~Desc
    dklet init
    case/portainer/dklet
    case/nginx-proxy/dklet
    gemstash/dklet
    pg/dklet -e prod
    redis/dklet -e prod
    hc/vault/dklet
  Desc
  Rake::Task[:devdns].invoke
end
