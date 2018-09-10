namespace :dklet do
  task :hi do
    hipath = 'tmp/hidklet'
    result = system <<~Desc
      mkdir -p #{File.dirname(hipath)}
      rm -f #{hipath}
      mkdklet #{hipath}
      #{hipath} help
      #{hipath} # main
      #{hipath} clean
    Desc

    if result
      puts 'everything ok' 
    else
      puts 'something wrong' 
    end
  end
end
