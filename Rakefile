desc 'batch test'
task :test do
  system <<~Desc
    dklet/try main
    dklet/try clean
    pg/dklet main
    pg/dklet clean
  Desc
end

task :dailyops do
  system <<~Desc
    case/nginx-proxy/dklet
    case/portainer/dklet
    case/gemstash/dklet

    pg/dklet -e prod
    redis/dklet -e prod
    case/metabase/dklet -e prod
    hc/vault/dklet -e prod
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
