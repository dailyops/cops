namespace :dklet do
  task :hi do
    result = system <<~Desc
      mkdir -p tmp
      rm -f tmp/hidklet
      mkdklet tmp/hidklet
      tmp/hidklet help
      tmp/hidklet
      tmp/hidklet clean
    Desc

    if result
      puts 'everything ok' 
    else
      puts 'something wrong' 
    end
  end
end
