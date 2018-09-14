namespace :dklet do
  desc 'hi to dklet'
  task :hi do
    hipath = 'tmp/hidklet'
    result = system <<~Desc
      mkdir -p #{File.dirname(hipath)}
      rm -f #{hipath}
      NOT_OPEN=1 mkdklet #{hipath}
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
      dklet/try main --clean
      pg/dklet main --clean
      pg/dklet clean
    Desc
  end
end

task default: ['dklet:test']
