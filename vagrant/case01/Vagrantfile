Vagrant.configure("2") do |config|
  (1..3).each do |i| 
      config.vm.define "hogwarts_#{i}" do |hogwarts| 
          hogwarts.vm.box = "ubuntu/xenial64"
          hogwarts.vm.hostname = "hogwarts-0#{i}"
          hogwarts.vm.network "public_network", bridge: "wlp3s0"
          hogwarts.vm.provision "shell", path: "docker-install.sh"
        end
    end
end