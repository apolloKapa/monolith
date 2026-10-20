{
  description = "NixOs - Hyprland + NVIDIA 4070 Ti";
  inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs/nixos-unstable";
    nix-gaming.url = "github:fufexan/nix-gaming";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs@{ self, nixpkgs, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        {
          nixpkgs.overlays = [
            (final: prev: {
              caelestia-shell =
                inputs.caelestia-shell.packages.x86_64-linux.caelestia-shell;
              caelestia-cli =
                inputs.caelestia-shell.inputs.caelestia-cli.packages.x86_64-linux.caelestia-cli;
              openldap = prev.openldap.overrideAttrs (_: {
                doCheck = false;
              });
            })
          ];
        }
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs       = true;
          home-manager.useUserPackages     = true;
          home-manager.backupFileExtension = "backup";
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users.apollo = { imports = [
            inputs.caelestia-shell.homeManagerModules.default
            ./home.nix
          ]; };
        }
      ];
    };
  };
}
