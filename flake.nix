{
  description = "A very basic zig flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    zig.url = "github:mitchellh/zig-overlay";
  };

  outputs = {
    self,
    nixpkgs,
    zig,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
    zigpkgs = zig.packages.${system};
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        zigpkgs.master
        zls
        xorg.libX11
        xorg.libX11.dev
        xorg.xorgserver
        xorg.xinit
      ];
    };
  };
}
