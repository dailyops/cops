namespace :dklet do
  task :gem do
    Dir.chdir('dklet') do
      system <<~Desc
        rake install
        gem query dklet --local
      Desc
    end
  end

  desc 'say hi to dklet'
  task hi: ['dklet:gem'] do
    hipath = 'tmp/hidklet'
    result = system <<~Desc
      mkdir -p #{File.dirname(hipath)}
      rm -f #{hipath}
      mkdklet #{hipath}
      #{hipath} help
      #{hipath} # main task
      #{hipath} clean --image
    Desc

    if result
      puts 'everything ok' 
    else
      puts 'something wrong'
    end
  end
end

task install: ['dklet:gem']

desc 'batch test'
task :test do
  system <<~Desc
    try/try main
    try/try clean
    pg/dklet main
    pg/dklet clean
  Desc
end

task :dailyops do
  system <<~Desc
    case/portainer/dklet
    case/nginx-proxy/dklet
    gemstash/dklet
    pg/dklet -e prod
    redis/dklet -e prod
    hc/vault/dklet
  Desc
  Rake::Task[:devdns].invoke
end

task :devdns do
  script = 'local/devdns/dklet'
  if File.exists?(script)
    system script
    puts "==run #{script}"
  else
    puts "not found #{script}"
  end
end

desc 'stat'
task :stat do
  system <<~Desc
    echo ==files total count:
    git ls-files | wc -l
    echo ==containers
    docker ps -f label=dklet_env
    echo ==images
    docker images -f label=dklet_env
  Desc
end
