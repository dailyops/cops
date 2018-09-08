require 'byebug'
require 'bundler/inline'
gemfile do
  source ENV['GEM_SOURCE'] || 'https://rubygems.org'
  gem "thor"
end
require 'thor'
require 'tempfile'
require 'erb'

module DockDSL
  def self.registry
    @_registry ||= {}
  end

  def registry
    DockDSL.registry
  end

  def dock_image
    "docklet/#{File.basename($PROGRAM_NAME, '.rb')}:newest"
  end

  # 触发脚本所在目录
  def script_path
    File.dirname($PROGRAM_NAME)
  end
  
  def set_file_for(name, str)
    registry[name] = ::Util.tmpfile_for(str)
  end

  def file_for(name)
    registry[name]
  end

  def file_content_for(name)
    File.read(registry[name])
  end

  def rendered_file_for(name, locals: {}, in_binding: binding)
    tmpl = file_content_for(name)
    erb = ERB.new(tmpl, nil, '%<>')
    rendered = erb.result(in_binding)
    ::Util.tmpfile_for(rendered)
  end

  def set_dockerfile(str)
    set_file_for(:dockerfile, str)
  end

  def dockerfile
    registry[:dockerfile]
  end
end

class DockletBase < Thor
  default_command :main
  class_option :debug, type: :boolean, default: false

  desc 'main', 'main entry'
  option :build, type: :boolean, default: true, banner: 'build image'
  option :clean, type: :boolean, default: false, banner: 'clean image'
  def main
    invoke :build, [], {} if options[:build]
    #puts "extend your logic by override with super"
  end

  desc 'runsh', 'docker run'
  option :cmd, banner: 'run command', default: 'sh'
  def runsh
    invoke :build, [], {}
    system "docker run --rm -it #{dock_image} #{options[:cmd]}"
  end

  desc 'console', 'get ruby console'
  def console
    byebug
    puts 'finish' if options[:debug]
  end

  desc 'hi', ''
  def hi
    puts 'just say hi'
  end

  desc 'daemon', 'docker run in daemon'
  option :opt, banner: 'run extra options'
  def daemon
    invoke :build, [], {}
    system "docker run --detach #{options[:opt]} #{dock_image}"
  end

  desc 'build', 'build image'
  def build
    #system "docker build --file xxx --tag #{dock_image} ."
    #donot need build context
    system <<~Desc
      cat #{dockerfile} | docker build --tag #{dock_image} -
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

  desc 'spec', 'display dockerfile spec'
  def spec
    puts File.read(dockerfile)
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
    include DockDSL

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
    file.path
  end
end

extend DockDSL
