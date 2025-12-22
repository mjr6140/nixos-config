{
  description = "Development and Gaming Desktop NixOS Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    antigravity = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cachyos-kernel = {
      url = "github:drakon64/nixos-cachyos-kernel";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, dms, antigravity, cachyos-kernel, ... }@inputs:
    let
      # Shared overlays for all hosts
      sharedOverlays = [
        (import ./overlays/pob-fix.nix)
      ];
    in
    {
      nixosConfigurations.nixos-desktop = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.hostPlatform = "x86_64-linux"; }
          ./hosts/nixos-desktop/configuration.nix
          inputs.cachyos-kernel.nixosModules.default
          ({ ... }: {
            nixpkgs.overlays = [
              inputs.cachyos-kernel.overlays.default
            ] ++ sharedOverlays;
          })
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.matt = import ./home/matt/home.nix;
            home-manager.extraSpecialArgs = { inherit inputs; isVM = false; };
            home-manager.backupFileExtension = "backup";
          }
          inputs.dms.nixosModules.dankMaterialShell
        ];
      };

      nixosConfigurations.nixos-vm = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.hostPlatform = "x86_64-linux"; }
          ./hosts/nixos-vm/configuration.nix
          ({ ... }: {
            nixpkgs.overlays = sharedOverlays;
          })
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.matt = import ./home/matt/home.nix;
            home-manager.extraSpecialArgs = { inherit inputs; isVM = true; };
            home-manager.backupFileExtension = "backup";
          }
          inputs.dms.nixosModules.dankMaterialShell
        ];
      };

      # Formatter for `nix fmt`
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
    };
}
