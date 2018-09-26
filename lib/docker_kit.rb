require 'bundler/setup'
Bundler.require :default
require 'byebug'
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
    val = registry[key]
    if val && val.respond_to?(:call)
      val = val.call
    end
    val
  end

  def register_docker_image(name)
    register :docker_image, name
  end

  def docker_image
    provided = fetch(:docker_image)
    return provided if provided
    imgname = dklet_script.basename('.rb').to_s
    if %w(dklet try).include?(imgname)
      imgname = script_path.basename.to_s
    end
    # NOTE: avoid use latest tag
    "docklet/#{imgname}:newest"
  end

  # 触发脚本所在目录
  def script_path
    dklet_script.realdirpath.dirname
  end

  def script_name
    name = dklet_script.basename('.rb').to_s
    return name unless name == 'dklet'
    "#{script_path.basename.to_s}_dklet"
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
  def write_dockerfile(str, path: nil)
    set_file_for(:dockerfile, str)
    register_build_root(path) if path
  end

  def raw_dockerfile
    fetch(:dockerfile)
  end

  def dockerfile
    rendered_file_for(:dockerfile)
  end

  # specfile for k8s resources spec manifest
  def write_specfile(str)
    set_file_for(:specfile, str)
  end

  def raw_specfile
    fetch(:specfile)
  end

  ## rendered in current context
  def specfile
    rendered_file_for(:specfile)
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
    ensure_docker_net(name) if build
  end

  def ensure_docker_net(name, driver: :bridge)
    #cmd = "docker network ls --filter name=#{name} -q"
    cmd = "docker network ls --format '{{.Name}}' --filter name=#{name}"
    netid = `#{cmd}`.chomp
    if netid.length < 1 || netid != name # avoid substr match
      netid = `docker network create #{name} --driver=#{driver}`
    end
    netid
  end

  ## project name for docker-compose
  def compose_name
    "#{fetch(:compose_name) || script_name}-#{env}"
  end

  # -f, --file
  # -p, --project-name to altertive project name, eg. default net prefix
  def compose_cmd
    "docker-compose -f #{specfile} --project-name #{compose_name} --project-directory #{approot}"
  end 

  def register_approot path
    register_path(:approot, path)
  end

  def approot
    fetch(:approot) || build_root || script_path
  end

  def register_app_tag(tag)
    app_tags << tag
  end

  def app_tags
    registry[:app_tags] ||= []
  end

  def smart_build_context_path
    # use explicitly specified, maybe nil
    return build_root if registry.has_key?(:build_root)
    # check build path dependent
    body = File.read(dockerfile)
    need_path = body =~ /^\s*(ADD|COPY)\s/i
    script_path if need_path
  end

  def register_build_root path
    register_path(:build_root, path)
  end

  def build_root
    fetch(:build_root)
  end

  def register_build_net net
    register(:build_net, net)
  end

  def build_net
    fetch(:build_net)
  end

  def register_path key, path
    path = Pathname(path) unless path.is_a?(Pathname)
    register key, path
  end

  def appname
    fetch(:appname) || approot.basename.to_s
  end

  def containers_for_image(img = docker_image)
    `docker ps -aq -f ancestor=#{img}`.split("\n")
  end

  def register_ops(cid)
    register :ops_container, cid
  end

  def ops_container
    fetch(:ops_container)
  end

  def smart_ops_container
    ops_container || containers_for_image.first
  end

  def container_missing
    puts "Not found container for image: #{docker_image}"
  end

  def register_default_env(str)
    register :default_env, str
  end

  def env
    ENV['APP_ENV'] || fetch(:default_env)
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
  def main
    invoke_clean if options[:preclean] && task_opts(:main)[:preclean] != false

    invoke_hooks_for(:main, type: :before)
    invoke :build, [], {} if options[:build] && task_opts(:main)[:build] != false
    invoke_hooks_for(:main)
  end

  desc 'console', 'get ruby console'
  def console
    byebug
    puts 'finish' if options[:debug]
  end

  desc 'log [CONTAINER]', 'logs in container'
  def log(cid = smart_ops_container)
    unless cid
      container_missing
      return
    end
    system <<~Desc
      docker logs -t -f --details #{cid}
    Desc
  end

  desc 'runsh [CONTAINER]', 'run into container'
  option :cmd, banner: 'run command in container'
  option :opts, banner: 'docker run options'
  option :exec, type: :boolean, default: true, banner: 'first exec existed container'
  option :allow_tmp, type: :boolean, default: true, banner: 'allow run tmp container'
  def runsh(cid = smart_ops_container)
    cmd = options[:cmd]
    if !cmd && respond_to?(:default_container_cmd)
      cmd = send(:default_container_cmd)
    end
    cmd ||=  'sh'
    if cid && options[:exec]
      dkcmd = "docker exec -it"
      dkcmd += " #{options[:opts]}" if options[:opts]
      dkcmd += " #{cid} #{cmd}"
      puts "run : #{dkcmd}"
      system dkcmd unless options[:dry]
      return
    end

    if options[:allow_tmp]
      dkcmd = "docker run --rm -it"
      dkcmd += " --network #{netname}" if netname
      dkcmd += " #{options[:opts]}" if options[:opts]
      dkcmd += " #{docker_image} #{cmd}"
      puts "run: #{dkcmd}"
      system dkcmd unless options[:dry]
    end
  end
  map "sh" => :runsh

  desc 'daemon', 'docker run in daemon'
  option :opts, banner: 'run extra options'
  def daemon
    invoke :build, [], {}
    system "docker run --detach #{options[:opts]} #{docker_image}" unless options[:dry]
  end

  desc 'build', 'build image'
  option :opts, banner: 'run extra options'
  def build
    return unless dockerfile

    unless options[:dry]
      invoke_hooks_for(:build, type: :before)
    end

    cmd = "docker build --tag #{docker_image}"
    net = build_net
    cmd += " --network #{net}" if net
    cmd += " #{options[:opts]}" if options[:opts]

    bpath = smart_build_context_path
    cmd = if bpath
      "#{cmd} --file #{dockerfile} #{bpath}"
    else # nil stand for do not need build context
      "cat #{dockerfile} | #{cmd} -"
    end
    puts "build command:\n  #{cmd}" if options[:debug]

    unless options[:dry]
      system cmd 
    end
  end

  desc 'note', 'display user notes'
  def note
    puts user_notes.join("\n")
  end

  desc 'clean', 'clean container artifacts'
  # keep cache reused
  option :image, type: :boolean, default: false, banner: 'clean user-derived images'
  def clean
    invoke_hooks_for(:clean, type: :before)

    cids = containers_for_image
    unless cids.empty?
      str_ids = cids.join(' ')
      system <<~Desc
        echo ==clean containers: #{str_ids}
        docker rm --force #{str_ids}
      Desc
    end

    invoke_hooks_for(:clean)

    if options[:image] && dockerfile
      system <<~Desc
        echo ==clean image: #{docker_image}
        docker rmi --force #{docker_image} 2>/dev/null
      Desc
    end
  end

  desc 'spec', 'display specs'
  option :spec, type: :boolean, default: true, banner: 'show rendered specfile'
  option :dockerfile, type: :boolean, default: true, banner: 'show Dockerfile'
  def spec
    if options[:spec] && specfile
      puts File.read(specfile)
      puts "# rendered at #{specfile}" if options[:debug]
    end
    if options[:dockerfile] && dockerfile
      puts File.read(dockerfile)
      puts "# Dockerfile at #{dockerfile} " if options[:debug]
    end
  end

  desc 'info', 'display dklet info in registry'
  def info
    pp registry
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
    ensure_docker_net(name)
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

  desc 'envrun [args]', 'deploy app'
  def envrun(denv=nil, *args)
    denv ||= env
    denv = case denv
      when 'dev'
        'development'
      when 'prod'
        'production'
      else
        denv
      end
    # fix env bad design 
    cmd = "APP_ENV=#{denv} #{dklet_script} #{args.join(' ')}"
    puts cmd if options[:debug] 
    unless options[:dry]
      system cmd
    end
  end
  map 'env' => 'envrun'

  desc 'comprun', 'compose run'
  def comprun(*args)
    cmd <<~Desc
      #{compose_cmd} #{args.join(' ')}
    Desc
    puts cmd if options[:debug]
    system cmd unless options[:dry]
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
  end
end

extend DockDSL
