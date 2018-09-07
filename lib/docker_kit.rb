require 'byebug'
require 'thor'
require 'tempfile'

class DockletBase < Thor
  default_command :main
  class_option :debug, type: :boolean, default: false

  desc 'main', 'main entry'
  option :build, type: :boolean, default: true, banner: 'build image'
  option :clean, type: :boolean, default: false, banner: 'clean image'
  def main
    invoke :build, [], {} if options[:build]
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
    system <<~Desc
      cat #{tmp_dockerfile.path} | docker build --tag #{dock_image} -
    Desc
  end

  desc 'clean', 'clean image'
  def clean
    system <<~Desc
      cids=$(docker ps -aq -f ancestor=#{dock_image})
      [ -n "$cids" ] && docker rm --force --volumes "$cids"
      docker rmi --force #{dock_image}
    Desc
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

  no_commands do
    def dock_image
      "docklet/#{File.basename($PROGRAM_NAME, '.rb')}:current"
    end

    def script_path
      File.dirname($PROGRAM_NAME)
    end

    def tmp_dockerfile
      @dfile ||= ::Util.tmpfile_for($dockerfile, prefix: 'docklet')
    end

    def invoke_clean
      invoke :clean, [], {}
    end
  end
end

module Util
  module_function

  def tmpfile_for(str, prefix: 'kc-tmp')
    file = Tempfile.new(prefix)
    file.write str
    file.close # save to disk
    # unlink清理问题：引用进程结束时自动删除？👍 
    file
  end
end
