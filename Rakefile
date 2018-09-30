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

namespace :dailyops do
  task :up do
    system <<~Desc
      dklet init
      case/portainer/dklet
      case/nginx-proxy/dklet
      gemstash/dklet
      pg/dklet -e prod
      redis/dklet -e prod
    Desc
  end

  task :down do
    system <<~Desc
      dklet netdown dailyops --force
    Desc
  end
end

task default: ['dklet:test']
