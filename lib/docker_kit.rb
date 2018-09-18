require 'bundler/inline'
gemfile do
  source ENV['GEM_SOURCE'] || 'https://rubygems.org'
  gem "byebug"
  gem "thor"
  #gem 'method_source' # not used now
end

require 'tempfile'
require 'erb'

module DockDSL
  def self.registry
    @_registry ||= {}
  end

  def registry
    DockDSL.registry
  end

  def register(key, value)
    registry[key] = value
  end

  def fetch(key)
    registry[key]
  end

  def register_docker_image(name, for_which: nil)
    register norm_docker_image_key(for_which), name
  end

  def docker_image(for_which = nil)
    provided = fetch(norm_docker_image_key(for_which))
    return provided if provided
    imgname = dklet_script.basename('.rb').to_s
    if imgname == 'dklet' # default name
      imgname = script_path.basename.to_s
    end
    # NOTE: avoid use latest tag
    "docklet/#{imgname}:newest"
  end

  def norm_docker_image_key(which=nil)
    return :docker_image unless which
    "docker_image_for_#{which}".to_sym
  end

  # 触发脚本所在目录
  def script_path
    dklet_script.realdirpath.dirname
  end

  def dklet_script
    Pathname($PROGRAM_NAME)
  end

  def dklet_lib_path
    Pathname(__dir__)
  end
  
  def set_file_for(name, str)
    register name, ::Util.tmpfile_for(str)
  end

  def file_for(name)
    fetch(name)
  end

  def file_content_for(name)
    fpath = fetch(name)
    return unless fpath
    File.read(fpath)
  end

  def rendered_file_for(name, locals: {}, in_binding: binding)
    tmpl = file_content_for(name)
    return unless tmpl
    erb = ERB.new(tmpl, nil, '%<>')
    rendered = erb.result(in_binding)
    ::Util.tmpfile_for(rendered)
  end

  # Dockerfile for image build
  def write_dockerfile(str, name: nil, path: nil)
    set_file_for(norm_dockerfile_key(name), str)
    use_build_path(path) if path
  end

  def dockerfile(name=nil)
    fetch(norm_dockerfile_key(name))
  end

  def use_build_path(path)
    return unless path
    path = path.to_s if path.is_a?(Pathname)
    register :user_build_path, path
  end

  def smart_build_context_path
    key = :user_build_path
    provided = fetch(key)
    return provided if registry.has_key?(key)
    body = File.read(dockerfile)
    # ADD xxx
    # COPY xxx
    need_path = body =~ /^\s*(ADD|COPY)\s/i
    return script_path if need_path
  end

  def norm_dockerfile_key(name = nil)
    return :dockerfile unless name
    "dockerfile_for_#{name}".to_sym
  end

  # specfile for k8s resources spec manifest
  def write_specfile(str, name: nil)
    set_file_for(norm_specfile_key(name), str)
  end

  def raw_specfile(name=nil)
    fetch(norm_specfile_key(name))
  end

  def norm_specfile_key(name = nil)
    return :specfile unless name
    "specfile_for_#{name}".to_sym
  end

  def disable(key)
    (registry[:disable] ||= {})[key] = true
  end

  def disabled?(key)
    (registry[:disable] ||= {})[key]
  end

  # main dsl
  def task(name = :main, opts={}, &blk)
    type = opts.delete(:type) || :after
    hooks_name = "#{name}_#{type}_hooks".to_sym 
    (registry[hooks_name] ||= []) << blk
    task_opts(name).merge!(opts) unless opts.empty?
  end

  def before_task(name = :main, &blk)
    task(name, type: :before, &blk)
  end 

  def task_opts(name = :main)
    key = "opts_for_task_#{name}".to_sym
    registry[key] ||= {}
  end

  def let_cli_magic_start!
    DockletCLI.start
  end

  def custom_commands &blk
    DockletCLI.class_eval &blk
  end

  def add_dsl &blk
    DockDSL.module_eval &blk
  end

  def add_note str
    (registry[:user_notes] ||= []) << str
  end

  def user_notes
    fetch(:user_notes)
  end

  # docker networking
  def netname
    fetch(:netname)
  end

  def register_net(name = :dailyops, build: false)
    register :netname, name
    build_docker_net(name) if build
  end

  def build_docker_net(name, driver: :bridge)
    #cmd = "docker network ls --filter name=#{name} -q"
    cmd = "docker network ls --format '{{.Name}}' --filter name=#{name}"
    netid = `#{cmd}`.chomp
    if netid.length < 1 || netid != name # avoid substr match
      netid = `docker network create #{name} --driver=#{driver}`
    end
    netid
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
  class_option :dry, type: :boolean, default: false

  desc 'main', 'main user entry'
  option :preclean, type: :boolean, default: true, banner: 'clean before do anything'
  option :build, type: :boolean, default: true, banner: 'build image'
  option :clean, type: :boolean, default: false, banner: 'clean image'
  def main
    invoke_clean if options[:preclean] && task_opts(:main)[:preclean] != false

    invoke_hooks_for(:main, type: :before)
    invoke :build, [], {} if options[:build] && task_opts(:main)[:build] != false
    invoke_hooks_for(:main)

    invoke_clean if options[:clean]
  end

  desc 'runsh', 'docker run eg. interactive sh'
  option :cmd, banner: 'run command', default: 'sh'
  option :opts, banner: 'run options'
  def runsh
    invoke :build, [], {}
    #byebug
    #puts "docker run --rm -it #{options[:opts]} #{docker_image} #{options[:cmd]}" if options[:debug]
    system "docker run --rm -it #{options[:opts]} #{docker_image} #{options[:cmd]}"
  end

  desc 'console', 'get ruby console'
  def console
    byebug
    puts 'finish' if options[:debug]
  end

  desc 'into', 'go into a running container'
  def into
    cids = `docker ps -aq -f ancestor=#{docker_image}`
    if cids.length > 0
      cid = cids.split("\n").first
      puts "run sh in container: #{cid} of #{docker_image}"
      system "docker exec -it #{cid} sh"
    else
      puts "No container for image #{docker_image}"
    end
  end

  desc 'daemon', 'docker run in daemon'
  option :opts, banner: 'run extra options'
  def daemon
    invoke :build, [], {}
    system "docker run --detach #{options[:opts]} #{docker_image}" unless options[:dry]
  end

  desc 'build', 'build image'
  def build
    return unless dockerfile
    bpath = smart_build_context_path
    cmd = if bpath
      "docker build --tag #{docker_image} --file #{dockerfile} #{bpath}"
    else # nil stand for do not need build context
      "cat #{dockerfile} | docker build --tag #{docker_image} -"
    end
    puts "build command:\n  #{cmd}" if options[:debug]

    unless options[:dry]
      invoke_hooks_for(:build, type: :before)
      system cmd 
    end
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
      if [ -n "$cids" ]; then
        echo ==clean containers: $cids
        # --volumes
        docker rm --force $cids
      fi
    Desc
    if dockerfile # user defined image
      system <<~Desc
        echo ==clean image: #{docker_image}
        docker rmi --force #{docker_image}
      Desc
    else
      puts 'no dockerfile provided' if options[:debug]
    end
    invoke_hooks_for(:clean)
  end

  desc 'spec', 'display specs'
  option :spec, type: :boolean, default: true, banner: 'show rendered specfile'
  option :dockerfile, type: :boolean, default: true, banner: 'show Dockerfile'
  def spec
    if options[:spec] && specfile
      puts File.read(specfile)
      #puts "# rendered at #{specfile}"
    end
    if options[:dockerfile] && dockerfile
      puts File.read(dockerfile)
      #puts "# Dockerfile at #{dockerfile} "
    end
  end

  desc 'image_name', 'display image name'
  def image_name
    puts docker_image
  end

  desc 'image', 'list related image'
  def image
    system "docker images #{docker_image}"
  end 

  desc 'ps', 'ps related containers'
  def ps
    system <<~Desc
      docker ps -f ancestor=#{docker_image} -a
    Desc
  end

  desc 'netup NAME', 'make networking'
  def netup(name = netname)
    return unless name
    build_docker_net(name)
    puts "network #{name} working"
  end

  desc 'netdown NAME', 'clean networking'
  option :force, type: :boolean, default: false, banner: 'rm forcely'
  def netdown(name = netname)
    return unless name
    global_nets = %i(dailyops)
    if global_nets.include?(name.to_sym)
      puts "donot clean global net: #{name}" if options[:debug]
      return
    end
    system "docker network rm #{name}"
    puts "network #{name} cleaned"
  end

  no_commands do
    include DockDSL

    def invoke_clean
      invoke :clean, [], {}
    end

    def invoke_hooks_for(name = :main, type: :after)
      hooks_name = "#{name}_#{type}_hooks".to_sym
      hooks = fetch(hooks_name)
      if hooks && !hooks.empty?
        hooks.each do |hook|
          # eval by receiver dierectly
          instance_eval &hook if hook.respond_to?(:call)
        end
      end
    end

    ## rendered in current context
    def specfile
      rendered_file_for(:specfile)
    end
  end
end

extend DockDSL
