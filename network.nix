{
  network.storage.legacy.databasefile = "./deployment.nixops";

  example = { pkgs, lib, ... }: let
    use-virtual-split = true;

    makeServiceNsPhysical = name: {
      systemd.services."${name}".serviceConfig.NetworkNamespacePath = "/var/run/netns/physical";
    };
    makeSocketNsPhysical = name: {
      systemd.sockets."${name}".socketConfig.NetworkNamespacePath = "/var/run/netns/physical";
    };
  in
    {
      deployment.targetEnv = "virtualbox";

      imports = [
        # networkmanager units:
        (makeServiceNsPhysical "NetworkManager")
        (makeServiceNsPhysical "NetworkManager-dispatcher")
        (makeServiceNsPhysical "NetworkManager-wait-online")
        (makeServiceNsPhysical "ModemManager")

        # without networkmanager:
        (makeServiceNsPhysical "dhcpcd")
        (makeSocketNsPhysical "sshd")

      ];


      nixpkgs.overlays = [
        (
          self: super: {
            dhcpcd = super.dhcpcd.override { udev = null; };
          }
        )
      ];

      networking = {
        hostId = "deadbeef";

        # note: enabling networkmanager messes stuff up for nixops, as it expects a specific IP.
        # from the physical expr:
        # networking = {
        #    privateIPv4 = "192.168.56.104";
        # };
        # but, this can be fixed with nmtui manually adding the preferred IP after
        # `nixops show-physical`.
        #
        # networkmanager.enable = true;
      };
      boot = {
        loader.timeout = lib.mkForce 2;

        systemdExecutable = toString (
          pkgs.writeShellScript "systemd-shim" ''
            echo "Here come some shenanigans."
            set -eux
            ${pkgs.iproute}/bin/ip netns add virtual
            ${pkgs.coreutils}/bin/touch /var/run/netns/physical
            ${pkgs.utillinux}/bin/mount -o bind /proc/self/ns/net /var/run/netns/physical
            exec ${pkgs.iproute}/bin/ip netns exec ${if use-virtual-split then "virtual" else "physical"} systemd
          ''
        );
      };

      services.openssh.startWhenNeeded = true;
      services.mingetty.autologinUser = "root";

      meh = ''
      ip link add dangerzone type veth peer name fantasyland

        # configure the "fantasyland" device, which is
        # the link TO fantasyland, and lives in "physical"
        ip addr add 169.254.1.1/24 dev fantasyland
        ip link set dev fantasyland netns physical
        ip netns exec physical ip link set fantasyland up

        ip netns exec physical bash -c 'echo 0 > /proc/sys/net/ipv4/conf/all/forwarding'
        ip netns exec physical bash -c 'echo 1 > /proc/sys/net/ipv4/conf/eth1/forwarding
        ip netns exec physical bash -c 'echo 1 > /proc/sys/net/ipv4/ip_forward'
        ip netns exec physical iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE
        ip netns exec physical iptables -I FORWARD -i eth1 -o fantasyland -m state --state RELATED,ESTABLISHED -j ACCEPT
        ip netns exec physical iptables -I FORWARD -i fantasyland -o eth1 -j ACCEPT


        

        # configure the "dangerzone" device, which is
        # the link TO dangerzone, and lives in "virtual"
        ip addr add 169.254.1.2/24 dev dangerzone
        ip link set dev dangerzone netns virtual
        ip netns exec virtual ip route add default via 169.254.1.1 dev dangerzone
        ip netns exec virtual ip link set dangerzone up

      '';
    };
}
