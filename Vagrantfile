required_plugins = %w(vagrant-vsphere nugrant vagrant-scp vagrant-hostmanager vagrant-triggers)
plugins_to_install = required_plugins.select {|plugin| not Vagrant.has_plugin? plugin}
if not plugins_to_install.empty?
  puts "Installing plugins: #{plugins_to_install.join(' ')}"
  if system "vagrant plugin install #{plugins_to_install.join(' ')}"
    exec "vagrant #{ARGV.join(' ')}"
  else
    abort "Installation of one or more plugins has failed. Aborting."
  end
end



Vagrant.configure("2") do |config|

  config.hostmanager.manage_host = false
  if config.user.key?('host') and config.user.host.key?('hostmanager') and config.user.host.hostmanager.key?('manage_host')
    config.hostmanager.manage_host = config.user.host.hostmanager.manage_host
  end
  config.hostmanager.manage_guest = true
  config.hostmanager.ignore_private_ip = false
  config.hostmanager.include_offline = true
  config.hostmanager.enabled = true


  # Information that is used by all instance being built in vsphere
  if config.user.vagrant['provider'] == 'vsphere'
    config.vm.provider :vsphere do |vsphere, override|
      # NOTE:
      config.vm.box = 'vsphere'
      config.vm.box_url = 'dummy.box'
      vsphere.host = config.user.vsphere.host
      vsphere.user = config.user.vsphere.user

      vsphere.password = config.user.vsphere.password
      vsphere.insecure = config.user.vsphere.insecure
      # TODO figure out how difficult and whether we want to add nfs support
      # Until we figure out if/how to use nfs, we need to rely on rsync
      override.nfs.functional = false
      # Typically vm.network should always be :public_network when using vsphere.
      # Don't use :private_network since the ip's are managed via DHCP.
      override.vm.network config.user.vsphere.network

      # this might need to change (depends on how vsphere is eventually setup to support enterprise)
      vsphere.compute_resource_name = 'DevOpsCls'

    end
  end


  config.user.theservers.each do |server|
    config.vm.define server['name'] do |node|

      if server.key?("synced_folders") and server.synced_folders.size > 0
        server.synced_folders.each do |dirpair|
          node.vm.synced_folder dirpair.hostpath, dirpair.guestpath, type: dirpair.type
        end
      end

      if server.key?("hostmanager") and server['hostmanager'].key?("aliases")
        node.hostmanager.aliases = server.hostmanager.aliases
      end


      # PROVIDERS
      node.vm.provider :vsphere do |vsphere|
        # per instance vsphere information
        vsphere.customization_spec_name = server.vsphere.customization_spec_name
        vsphere.template_name = server.vsphere.template_name
        vsphere.name = config.user.developer.id + "-" + server.name # please don't change this, helps to avoid collision
      end


      # PROVISIONERS
      node.vm.provision :hostmanager



      if server.type == 'dockerhost'
        node.hostmanager.aliases = server.name + ".sandbox.lowes.dev"
        node.vm.hostname = server.name

        # Add ansible roles to local installation of ansible
        # TODO(phart) move this into the ansible provision step
        #https://www.vagrantup.com/docs/provisioning/ansible_common.html
        node.trigger.before :provision do |local|
          run "ansible-galaxy install mongrelion.docker"
        end

        # # TODO(phart)issue #1 https://github.com/docker/for-linux/issues/20 can't use manager-docker-host until resolved.  the following two lines are done instead
        # node.vm.provision "shell", inline: "sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo"
        # node.vm.provision "shell", inline: "yum install --setopt=obsoletes=0  docker-ce-17.03.2.ce-1.el7.centos.x86_64 docker-ce-selinux-17.03.2.ce-1.el7.centos.noarch # on a new system with yum repo defined, forcing older version and ignoring obsoletes introduced by 17.06.0 "


        # Update vm to latest
        node.vm.provision "shell", inline: "yum update -y"
        # create a ansible inventory file for this project
        node.vm.provision "ansible" do |localconfig|
          # If this errors, make sure you have added the line
          # localhost ansible_connection=local ansible_become_user='insert your id' ansible_user='insert your id'
          # into your ansible inventory file on your local machine.
          # and that the file is the value for the argument localconfig.inventory_path
          localconfig.verbose = "-vvvv"
          # Override vagrants default of running only on vm it created.
          localconfig.limit = "all"
          localconfig.become = true
          localconfig.become_user = "phart"
          localconfig.playbook = "localhost/main.yml"
          localconfig.inventory_path = "/Users/phart/.ansible/hosts"
          localconfig.extra_vars = {
              username: config.user.developer.id,
              hostname: server.name
          }
        end
        # Install Docker on the vm TODO(phart) reenable once issue #1 is resolved.
        node.vm.provision "ansible" do |docker|
          # install basic dockerhost software
          docker.verbose = "-vvv"
          docker.inventory_path = "localhost/hosts"
          docker.become = true
          docker.become_user = "root"
          docker.playbook = "manage-docker-host/vagrant.yml"

        end
        node.vm.provision "shell", inline: "sudo -H -u vagrant bash -c '/vagrant/scripts/installAnsibleContainer.sh'"
        node.vm.provision "shell", inline: "sudo -H -u vagrant bash -c 'cd /vagrant/manage-containers; ./buildAndDeploy.sh'"

        #  https://ansible.github.io/ansible-container-demo/

      end

      if config.user.developer.key?('poststepscript')
        file = File.open("#{config.user.developer['poststepscript']}")
        contents = file.read
        eval(contents)
      end
    end
  end
end

