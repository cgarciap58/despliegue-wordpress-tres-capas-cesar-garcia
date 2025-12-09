
  Vagrant.configure("2") do |config|
    config.vm.box = "debian/bookworm64"
    config.vm.box_version = "12.20250126.1"

    config.vm.define "NFSCesarGarcia" do |nfs|
      nfs.vm.hostname = "NFSCesarGarcia"
      nfs.vm.network "private_network", ip: "192.168.10.25", virtualbox__intnet: "LBNet"
      nfs.vm.provision "shell", path: "provisionNFS.sh"
    end

    config.vm.define "LBSCesarGarcia" do |lbs|
      lbs.vm.hostname = "LBSCesarGarcia"
      lbs.vm.network "private_network", ip: "192.168.10.10", virtualbox__intnet: "LBNet"
      lbs.vm.network "forwarded_port", guest: 443, host: 8443
      lbs.vm.provision "shell", path: "provisionLB.sh"
    end

    config.vm.define "WS1CesarGarcia" do |ws1|
      ws1.vm.hostname = "WS1CesarGarcia"
      ws1.vm.network "private_network", ip: "192.168.10.21", virtualbox__intnet: "LBNet"
      ws1.vm.network "private_network", ip: "192.168.20.21", virtualbox__intnet: "DBNet"
      ws1.vm.provision "shell", path: "provisionWeb.sh"
    end

    config.vm.define "WS2CesarGarcia" do |ws2|
      ws2.vm.hostname = "WS2CesarGarcia"
      ws2.vm.network "private_network", ip: "192.168.10.22", virtualbox__intnet: "LBNet"
      ws2.vm.network "private_network", ip: "192.168.20.22", virtualbox__intnet: "DBNet"
      ws2.vm.provision "shell", path: "provisionWeb.sh"
    end

    config.vm.define "DB1CesarGarcia" do |db1|
      db1.vm.hostname = "DB1CesarGarcia"
      db1.vm.network "private_network", ip: "192.168.20.50", virtualbox__intnet: "DBNet"
      db1.vm.provision "shell", path: "provisionDB.sh"  
    end
end
