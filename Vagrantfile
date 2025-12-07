
  Vagrant.configure("2") do |config|
    config.vm.box = "debian/bookworm64"
    config.vm.box_version = "12.20250126.1"

    config.vm.define "NFS" do |nfs|
      nfs.vm.hostname = "NFS"
      nfs.vm.network "private_network", ip: "192.168.10.25", virtualbox__intnet: "LBNet"
      nfs.vm.provision "shell", path: "provisionNFS.sh"
    end

    config.vm.define "LBS" do |lbs|
      lbs.vm.hostname = "LBS"
      lbs.vm.network "private_network", ip: "192.168.10.10", virtualbox__intnet: "LBNet"
      lbs.vm.network "forwarded_port", guest: 80, host: 8080
      lbs.vm.provision "shell", path: "provisionLB.sh"
    end

    config.vm.define "WS1" do |ws1|
      ws1.vm.hostname = "WS1"
      ws1.vm.network "private_network", ip: "192.168.10.21", virtualbox__intnet: "LBNet"
      ws1.vm.network "private_network", ip: "192.168.20.21", virtualbox__intnet: "DBNet"
      ws1.vm.network "forwarded_port", guest: 80, host: 8081
      ws1.vm.provision "shell", path: "provisionWeb.sh"
    end

    config.vm.define "WS2" do |ws2|
      ws2.vm.hostname = "WS2"
      ws2.vm.network "private_network", ip: "192.168.10.22", virtualbox__intnet: "LBNet"
      ws2.vm.network "private_network", ip: "192.168.20.22", virtualbox__intnet: "DBNet"
      ws2.vm.network "forwarded_port", guest: 80, host: 8082
      ws2.vm.provision "shell", path: "provisionWeb.sh"
    end

    config.vm.define "DB1" do |db1|
      db1.vm.hostname = "DB1"
      db1.vm.network "private_network", ip: "192.168.20.50", virtualbox__intnet: "DBNet"
      db1.vm.provision "shell", path: "provisionDB.sh"  
    end
end
