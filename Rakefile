desc 'batch test'
task :test do
  system <<~Desc
    dklet/try main
    dklet/try clean
    db/pg111/dklet main
    db/pg111/dklet clean
  Desc
end

task :dailyops do
  system <<~Desc
    dkl netup dailyops
    nginx-proxy/dklet -e prod
    ruby/gemstash/dklet -e prod
    case/portainer/dklet -e prod
    db/pg/pg111 -e prod
    db/redis/dklet -e prod
    #db/metabase/dklet -e prod
    #vault/dklet.rb -e prod
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
