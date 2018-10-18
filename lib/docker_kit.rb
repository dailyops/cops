ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)
require 'bundler/setup'
Bundler.require :default
require 'byebug'
require 'erb'
require_relative 'util'

module DockDSL
  def self.registry
    @_registry ||= {}
  end

  def registry
    DockDSL.registry
  end

  def add_dsl &blk
    DockDSL.module_eval &blk
  end

  def self.dsl_methods
    @_dsl_methods ||= []
  end

  def dsl_methods
    DockDSL.dsl_methods
  end

  def self.dsl_method(mthd)
    dsl_methods << mthd
    define_method(mthd) do
      fetch_with_default(mthd)
    end
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

  def fetch_with_default(key)
    provided = fetch(key)
    return provided if provided
    mthd = "default_#{key}"
    send(mthd) if respond_to?(mthd)
  end

  def register_docker_image(name)
    register :docker_image, name
  end

  # release is not relevant
  def default_docker_image
    "#{env}/#{appname}:#{image_tag}"
  end

  def default_image_tag
    "edge"
  end

  def default_image_labels
    app_labels = image_label_hash.map{|k, v| [k,v].join('=') }.join(' ')
    "maintainer=dailyops built_from=docklet #{app_labels}"
  end

  def image_label_hash
    {
      dklet_app: appname,
      dklet_env: env
    }
  end

  def release_label_hash
    image_label_hash.merge(dklet_release: app_release)
  end

  # maybe from external image
  def dkrun_cmd(labeled: true, opts: nil, named: false)
    cmd = "docker run"
    if labeled
      release_labels = release_label_hash.map do |k, v|
        "--label=#{k}=#{v}"
      end.join(' ')
      cmd += " #{release_labels}"
    end
    cmd += " --net #{netname}" if netname
    cmd += " --name #{container_name}" if named
    cmd += " #{opts}" if opts
    cmd
  end

  def dktmprun(opts: nil)
    cmd = dkrun_cmd(opts: "--rm -i #{opts}", labeled: false)
    "#{cmd} #{docker_image}"
  end

  def container_filters_for_release
    release_label_hash.map do |k, v|
      "--filter label=#{k}=#{v}"
    end.join(' ')
  end

  def containers_for_release
    `docker ps -aq #{container_filters_for_release}`.split("\n")
  end

  # Note: if img1:t1 = img2:t2 points to same image hashid, they will be selected as same
  def containers_for_image(img = docker_image)
    `docker ps -aq -f ancestor=#{img}`.split("\n")
  end

  def containers_in_net(net = netname)
    `docker ps -aq -f network=#{net}`.split("\n")
  end 

  def dklet_script
    Pathname($PROGRAM_NAME)
  end

  # 触发脚本所在(绝对)路径
  def script_path
    dklet_script.realdirpath.dirname
  end

  # use <parent_path_name>_<script_file_name> to ensure possible unique
  def script_name # not file name
    sname = fetch(:script_name)
    return sname if sname
    name = dklet_script.basename('.rb').to_s
    pname = script_path.basename.to_s
    "#{pname}_#{name}"
  end

  def dklet_lib_path
    Pathname(__dir__)
  end

  def dklet_home
    dklet_lib_path.join('..')
  end

  def dklet_tmp_path
    dklet_home.join('tmp')
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

  def dklet_config_for(name)
    p = Pathname("/dkconf/#{full_release_name}")
    p.mkpath unless p.directory?
    p.join(name)
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

  def add_note str
    (registry[:user_notes] ||= []) << str
  end

  def user_notes
    fetch(:user_notes)
  end

  # docker networking
  def register_net(name = :dailyops, build: false)
    register :netname, name
    ensure_docker_net(name) if build
  end

  def netname
    fetch(:netname)
  end

  def ensure_docker_net(name, driver: :bridge)
    unless netid = find_net(name)
      puts "create new network: #{name}"
      netid = `docker network create #{name} --label #{label_pair(:name, name)} --driver=#{driver}`
    end
    netid
  end

  # use label (not name) filter to avoid str part match
  def find_net(name)
    cmd = "docker network ls -q --filter label=#{label_pair(:name, name)}"
    netid = `#{cmd}`.chomp
    return netid unless netid.empty?
    nil
  end

  def label_key(key, prefix: true)
    prefix ? "docklet.#{key}" : key
  end

  # key=value pair
  def label_pair(key, val, prefix: true)
    [label_key(key, prefix: prefix), val].join('=')
  end

  ## project name for docker-compose
  def compose_name
    "#{fetch(:compose_name) || appname}_#{env}"
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

  def appname
    fetch(:appname) || script_name
  end

  # take into acccount: app, env, app_release
  def full_release_name
    [env, appname, app_release].compact.join('_')
  end

  # make path friendly 
  def release_path_name
    full_release_name.gsub(/_/, '-')
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

  def register_ops(cid)
    register :ops_container, cid
  end

  def default_ops_container
    containers_for_release.first # || container_name
  end

  def default_container_name
    full_release_name
  end

  def container_missing
    puts "Not found container for image: #{docker_image}"
  end

  def register_default_env(str)
    register :default_env, str
  end

  def env
    ENV['APP_ENV'] || fetch(:default_env) || 'dev'
  end

  # 标识一次运行发布的用途, 如redis for hirails-only
  def app_release
    ENV['APP_RELEASE'] || 'default'
  end

  def volumes_root
    vols_root = "#{ENV['HOME']}/DockerVolumes"
    root = fetch(:volumes_root) || if File.directory?(vols_root)
        # friendly to File sharing on Docker for Mac
        vols_root
      else
        '~/docker-volumes'
      end
    Pathname(root)
  end

  def default_app_volumes
    volumes_root.join(release_path_name)
  end

  def register_default_cmd str
    register :default_cmd, str
  end

  def default_cmd
    fetch(:default_cmd)
  end
end

class DockletCLI < Thor
  #include Thor::Actions

  default_command :main
  class_option :debug, type: :boolean, default: false, banner: 'in debug mode, more log'
  class_option :dry, type: :boolean, default: false, banner: 'dry run'
  class_option :quiet, type: :boolean, default: false, banner: 'keep quiet'
  class_option :force, type: :boolean, default: false, banner: 'force do'
  class_option :env, banner: 'app env', aliases: ['-e']
  class_option :release, banner: 'what app release for', aliases: ['-r']

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
    pp registry
    byebug 
    puts "=ok"
  end

  desc 'log [CONTAINER]', 'logs in container'
  def log(cid = ops_container)
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
  option :tmp, type: :boolean, default: false, banner: 'allow run tmp container'
  def runsh(cid = ops_container)
    tmprun = options[:tmp]
    if tmprun
      dkcmd = "docker run -t -d" 
      dkcmd += " --network #{netname}" if netname
      dkcmd += " #{options[:opts]}" if options[:opts]
      cid = `#{dkcmd} #{docker_image} sleep 3d`.chomp
      puts "==run tmp container: #{cid}" unless options[:quiet]
    end

    abort "No container found!" unless cid

    cmd = options[:cmd] || default_cmd || 'sh'
    puts "run : #{cmd}" unless options[:quiet]

    if cmd == 'sh' # simple case
      cmds = <<~Desc
        docker exec -it #{options[:opts]} #{cid} #{cmd}
      Desc
    else
      tfile = ::Util.tmpfile_for cmd
      dst_file = "/tmp/dklet-#{File.basename(tfile)}-#{rand(10000)}"
      cmds = <<~Desc
        docker cp #{tfile} #{cid}:#{dst_file}
        docker exec -it #{options[:opts]} #{cid} sh -c 'sh #{dst_file} && rm -f #{dst_file}'
      Desc
    end
    puts cmds if options[:debug]
    system cmds unless options[:dry]

    if tmprun
      system <<~Desc
        docker rm -f #{cid}
      Desc
    end
  end
  map "sh" => :runsh

  desc 'daemon', 'docker run in daemon'
  option :opts, banner: 'run extra options'
  def daemon
    invoke :build, [], {}
    system "docker run -d #{options[:opts]} #{docker_image}" unless options[:dry]
  end

  desc 'build', 'build image'
  option :opts, banner: 'build extra options like --no-cache'
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

    system cmd unless options[:dry]
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

    unless specfile # do not clean container if compose-file exists
      cids = containers_for_release
      unless cids.empty?
        str_ids = cids.join(' ')
        system <<~Desc
          echo ==clean containers: #{str_ids}
          docker rm --force #{str_ids}
        Desc
      end
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

  desc 'image_name', 'display image name'
  def image_name
    puts docker_image
  end

  desc 'image', 'list related image'
  def image
    system "docker images #{docker_image}"
  end 

  desc 'ps', 'ps related containers'
  option :imaged, type: :boolean, default: false, banner: 'same image digest'
  def ps
    cmd = if options[:imaged]
        "docker ps -f ancestor=#{docker_image} -a"
      else
        "docker ps #{container_filters_for_release} -a"
      end
    puts cmd if options[:debug]
    system cmd unless options[:dry]
  end

  desc 'netup [NETNAME]', 'make networking'
  def netup(net = netname)
    return unless net
    ensure_docker_net(net)
    puts "network #{net} working"
  end

  desc 'netdown [NETNAME]', 'clean networking'
  def netdown(net = netname)
    puts "cleaning net: #{net}" if options[:debug]
    return unless net
    return unless find_net(net)

    cids = containers_in_net(net)
    binded = !cids.empty?
    if binded 
      if options[:force] || yes?("#{cids.size} containers linked, FORCELY remove?")
        system "docker rm -f #{cids.join(' ')}"
        binded = false
      end
    end
    if binded
      puts "#{net} has binded resources, skipped"
    else
      system "docker network rm #{net}"
      puts "network #{net} cleaned"
    end
  end

  desc 'netps [NETNAME]', 'ps in a network' 
  def netps(net = netname)
    return unless net
    system <<~Desc
      docker ps -f network=#{net} -a
    Desc
  end

  desc 'netls', 'list networks' 
  def netls()
    system <<~Desc
      docker network ls
    Desc
  end

  desc 'comprun', 'compose run'
  def comprun(*args)
    cmd = <<~Desc
      #{compose_cmd} #{args.join(' ')}
    Desc
    puts cmd if options[:debug]
    system cmd unless options[:dry]
  end

  desc 'vols', 'ls volumes'
  def vols
    system <<~Desc
      ls -l #{volumes_root}/
    Desc
  end

  desc 'clear_app_volumes', 'clear app volumes'
  def clear_app_volumes
    if app_volumes.directory?
      if options[:force] || yes?("Remove app volumes dir data?")
        app_volumes.rmtree
      end
    end
  end

  desc 'inspect_info', 'inspect info'
  option :image, type: :boolean, default: false, aliases: ['-i'], banner: 'inspect image'
  option :container, type: :boolean, default: false, aliases: ['-c'], banner: 'inspect container'
  def inspect_info
    cmd = nil
    if options[:image]
      cmd = "docker inspect #{docker_image}"
    elsif options[:container]
      cid = containers_for_release.first || container_name || ops_container
      cmd = "docker inspect #{cid}"
    else
      h = {
        script: dklet_script,
        script_path: script_path,
        script_name: script_name,
        appname: appname,
        env: env,
        release: app_release,
        full_release_name: full_release_name,
        container_name: container_name,
        image: docker_image,
        approot: approot,
        build_root: build_root,
        build_net: build_net,
        release_labels: release_label_hash,
        network: netname,
        voluemes_root: volumes_root,
        app_volumes: app_volumes,
        dsl_methods: dsl_methods,
        registry: registry
      }
      pp h
    end
    system cmd if cmd
  end
  map 'inspect' => 'inspect_info'
  map 'info' => 'inspect_info'

  desc 'mock1', ''
  def mock1(time)
    puts "invoked at #{time}"
  end

  desc 'mock2', ''
  def mock2
    invoke :mock1, [Time.now]
    puts 'first invoked'
    invoke :mock1, [Time.now]
    puts 'sencond invoked'

    invoke2 :mock1, [Time.now], {}
    puts 'third invoked'
    invoke2 :mock1, [Time.now], {}
    puts '4th invoked'
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

    # https://github.com/erikhuda/thor/issues/73
    def invoke2(task, args, options)
      (klass, task) = Thor::Util.find_class_and_command_by_namespace(task)
      klass.new.invoke(task, args, options)
    end

    def container_run(cmds, opts = nil)
      cmds = cmds.join("\n") if cmds.is_a?(Array)
      opts = (opts||{}).merge(cmd: cmds).merge(options.slice('quiet', 'dry'))
      invoke :runsh, [], opts
    end

    # encapsulate run commands behaviors in system
    def system_run(cmds, opts={})
      unless options[:quiet]
        puts cmds
      end
      unless options[:dry]
        system cmds
      end
    end
  end
end

%i(
  docker_image
  image_tag
  image_labels
  container_name
  ops_container
  app_volumes
).each{|m| DockDSL.dsl_method(m) }

extend DockDSL
