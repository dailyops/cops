#!/usr/bin/env rundklet
add_note <<~Note
  explore Docker for Mac settings
Note

custom_commands do
  desc '', ''
  def profile
    system <<~Desc
      echo ==local settings
      ls -l ~/.docker
      echo ==host data
      ls -l ~/Library/Containers/com.docker.docker/Data/
    Desc

  end

  desc '', ''
  def filesharing
    # DockerForMac --> Preferences --> File Sharing settings
    # https://docs.docker.com/docker-for-mac/osxfs/
    # whitelist can bind mount into containers
    # Note: these directories mounted at / on the vm
    system <<~Desc
      echo ==internal vm root / 
      docker run -it -v /:/vmroot alpine ls -lh /vmroot
      # 注意这里mount的主机目录是通过内部的vm起作用的，即先通过设置挂载到vm上，然后再挂载到容器内
    Desc
    # so you can list images files like on a linux host by containers
  end

  desc '', ''
  def host_images
    system <<~Desc
      echo ==host disk images 
      ls -lh ~/Library/Containers/com.docker.docker/Data/vms/0
      du -h ~/Library/Containers/com.docker.docker/Data/vms/0/Docker.raw
    Desc
  end
end

__END__
https://docs.docker.com/docker-for-mac/faqs/

What is the disk image?
The containers and images are stored in a disk image named Docker.raw or Docker.qcow2 depending on your settings (see below).  By default, the disk image is stored in 
~/Library/Containers/com.docker.docker/Data/vms/0

hyperkit
