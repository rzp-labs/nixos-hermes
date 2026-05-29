{ lib, pkgs, ... }:
{
  systemd.services.golden = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.ExecStart = "${pkgs.hello}/bin/hello";
  };
}
