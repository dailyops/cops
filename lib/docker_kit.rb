require 'bundler/inline'
gemfile do
  source ENV['GEM_SOURCE'] || 'https://rubygems.org'
  gem "byebug"
  gem "thor"
end
require 'byebug'
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

  def docker_image
    # NOTE: avoid use latest tag
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

  def task(name = :main, type: :after, &blk)
    hooks_name = "#{name}_#{type}_hooks".to_sym 
    (registry[hooks_name] ||= []) << blk
  end

  def before_task(name = :main, &blk)
    task(name, type: :before, &blk)
  end 

  def let_cli_magic_start!
    DockletCLI.start
  end

  def extend_commands &blk
    DockletCLI.class_eval &blk
  end

  def add_dsl &blk
    DockDSL.module_eval &blk
  end

  def add_note str
    (registry[:user_notes] ||= []) << str
  end

  def user_notes
    registry[:user_notes]
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

class DockletCLI < Thor
  default_command :main
  class_option :debug, type: :boolean, default: false

  desc 'main', 'main entry'
  option :build, type: :boolean, default: true, banner: 'build image'
  option :clean, type: :boolean, default: false, banner: 'clean image'
  def main
    invoke_hooks_for(:main, type: :before)
    invoke :build, [], {} if options[:build]
    invoke_hooks_for(:main)
    invoke :clean, [], {} if options[:clean]
  end

  desc 'runsh', 'docker run eg. interactive sh'
  option :cmd, banner: 'run command', default: 'sh'
  def runsh
    invoke :build, [], {}
    system "docker run --rm -it #{docker_image} #{options[:cmd]}"
  end

  desc 'console', 'get ruby console'
  def console
    byebug
    puts 'finish' if options[:debug]
  end

  desc 'daemon', 'docker run in daemon'
  option :opt, banner: 'run extra options'
  def daemon
    invoke :build, [], {}
    system "docker run --detach #{options[:opt]} #{docker_image}"
  end

  desc 'build', 'build image'
  def build
    #system "docker build --file xxx --tag #{docker_image} ."
    #donot need build context
    system <<~Desc
      cat #{dockerfile} | docker build --tag #{docker_image} -
    Desc
  end

  desc 'log', 'log container todo'
  def log
    puts <<~Desc
      docker logs -t -f --details containerxxx 
    Desc
  end

  desc 'note', 'display user notes'
  def note
    puts user_notes.join("\n")
  end

  desc 'clean', 'clean image'
  def clean
    invoke_hooks_for(:clean, type: :before)
    system <<~Desc
      cids=$(docker ps -aq -f ancestor=#{docker_image})
      [ -n "$cids" ] && docker rm --force --volumes "$cids"
      docker rmi --force #{docker_image}
    Desc
    invoke_hooks_for(:clean)
  end

  desc 'spec', 'display spec eg. Dockerfile'
  def spec
    puts "## Dockerfile spec"
    puts File.read(dockerfile)
    invoke_hooks_for(:spec)
  end

  desc 'image_name', 'display image name'
  def image_name
    puts docker_image
  end

  desc 'image', 'list related image'
  def image
    system "docker images #{docker_image}"
  end 

  no_commands do
    include DockDSL

    def invoke_clean
      invoke :clean, [], {}
    end

    def invoke_hooks_for(name = :main, type: :after)
      hooks_name = "#{name}_#{type}_hooks".to_sym
      hooks = registry[hooks_name]
      if hooks && !hooks.empty?
        hooks.each do |hook|
          # eval by receiver dierectly
          instance_eval &hook if hook.respond_to?(:call)
        end
      end
    end
  end
end

extend DockDSL
