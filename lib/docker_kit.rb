require 'byebug'
require 'thor'
require 'tempfile'

class NoUserMainDefined < StandardError; end

class DockletBase < Thor
  default_command :main
  class_option :debug, type: :boolean, default: false

  desc 'main', 'main entry'
  option :build, type: :boolean, default: true, banner: 'build image'
  option :clean, type: :boolean, default: false, banner: 'clean image'
  def main
    invoke :build, [], {} if options[:build]
    begin
      user_main
    rescue NoUserMainDefined
      puts "==no user_main defined" if options[:debug]
      system <<~Script
        docker run --rm --env name=test #{dock_image} env
      Script
    end
    invoke :clean, [], {} if options[:clean]
  end

  desc 'runsh', 'docker run'
  option :cmd, banner: 'run command', default: 'sh'
  def runsh
    invoke :build, [], {}
    system "docker run --rm -it #{dock_image} #{options[:cmd]}"
  end

  desc 'daemon', 'docker run in daemon'
  option :opt, banner: 'run extra options'
  def daemon
    invoke :build, [], {}
    system "docker run --detach #{options[:opt]} #{dock_image}"
  end

  desc 'build', 'build image'
  def build
    file = Tempfile.new('docklet')
    begin
      file.write $dockerfile
      file.close # save to disk
      system <<~Script
        cat #{file.path} | docker build --tag #{dock_image} -
      Script
    ensure
      file.unlink
    end
  end

  desc 'clean', 'clean image'
  def clean
    system "docker rmi #{dock_image}"
  end

  desc 'dockerfile', 'display dockerfile'
  def dockerfile
    puts $dockerfile
  end

  desc 'image_name', 'display image name'
  def image_name
    puts dock_image
  end

  desc 'image', 'list related image'
  def image
    system "docker images #{dock_image}"
  end 

  no_tasks do
    def dock_image
      "docklet/#{File.basename($PROGRAM_NAME, '.rb')}"
    end

    def user_main
      # redefine your logic in subclass
      raise NoUserMainDefined.new
    end
  end
end
