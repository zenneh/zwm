{
  description = "A very basic zig flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    zigpkgs.url = "github:mitchellh/zig-overlay";
  };

  outputs = {
    self,
    nixpkgs,
    zigpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
    zig_master = zigpkgs.packages.${system}.master;
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        zig
        zls
        xorg.libX11
        xorg.libX11.dev
        xorg.xorgserver
        xorg.xinit
      ];
    };
  };
}
