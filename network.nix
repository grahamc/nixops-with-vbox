{
  network.storage.legacy.databasefile = "./deployment.nixops";

  example = { pkgs, lib, ... }: {
    deployment.targetEnv = "virtualbox";
    boot = {
      loader.timeout = lib.mkForce 2;

      systemdExecutable = toString (
        pkgs.writeShellScript "systemd-shim" ''
          echo "Here come some shenanigans."
          set -eux
          ${pkgs.iproute}/bin/ip netns add virtual
          ${pkgs.coreutils}/bin/touch /var/run/netns/physical
          ${pkgs.utillinux}/bin/mount -o bind /proc/self/ns/net /var/run/netns/physical
          exec ${pkgs.iproute}/bin/ip netns exec ${if true then "physical" else "virtual"} systemd
        ''
      );
    };

    services.mingetty.autologinUser = "root";
    systemd.services.systemd-udevd.serviceConfig = {
      SystemCallFilter = "@debug";
      NetworkNamespacePath = "/var/run/netns/physical";
      ExecStart = [ "" "${pkgs.strace}/bin/strace -f ${pkgs.systemd}/lib/systemd/systemd-udevd" ];
    };
  };
}
