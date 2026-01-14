{
  description = "A Nix-flake-based Go development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable"; # unstable Nixpkgs

  outputs =
    { self, ... }@inputs:

    let
      goVersion = 25; # Change this to update the whole stack

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forEachSupportedSystem =
        f:
        inputs.nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            pkgs = import inputs.nixpkgs {
              inherit system;
              overlays = [ inputs.self.overlays.default ];
            };
          }
        );
    in
    {
      overlays.default = final: prev: {
        go = final."go_1_${toString goVersion}";
      };

      devShells = forEachSupportedSystem (
        { pkgs }:
        {
          default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              # go (version is specified by overlay)
              go

              # goimports, godoc, etc.
              gotools

              # https://github.com/golangci/golangci-lint
              golangci-lint
              just
              skopeo
              gzip

              sing-box
            ];
          };
        }
      );

      packages = forEachSupportedSystem (
        { pkgs }:
        let
          app = pkgs.buildGoModule {
            pname = "ros-proxy-controller";
            version = "0.1.0-1.21.15";
            src = ./.;
            vendorHash = null;
          };
        in
        rec {
          default = app;
          docker = pkgs.dockerTools.buildLayeredImage {
            name = "nykma/ros-proxy-container";
            tag = "latest-${pkgs.system}";
            contents = with pkgs; [
              tzdata
              cacert
              nftables
              tini
              sing-box
              app
            ];
            config = {
              Entrypoint = [
                "${pkgs.tini}/bin/tini"
                "--"
              ];
              Cmd = [
                "${app}/bin/ros-sing-box"
              ];
            };
          };
          docker-with-tag = docker.override { tag = "${app.version}-${pkgs.system}"; };
        }
      );
    };
}
