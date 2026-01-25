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
    claude-desktop = {
      url = "github:k3d3/claude-desktop-linux-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
    };
  };

  outputs = { self, nixpkgs, home-manager, dms, antigravity, claude-desktop, llm-agents, vscode-extensions, ... }@inputs:
    let
      system = "x86_64-linux";
      # VM-only overlay for Path of Building software rendering
      vmOverlays = [
        (import ./overlays/pob-fix.nix)
      ];
    in
    {
      nixosConfigurations.nixos-desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/nixos-desktop/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.matt = import ./home/matt/home.nix;
            home-manager.extraSpecialArgs = { inherit inputs; isVM = false; };
            home-manager.backupFileExtension = "backup";
          }
          inputs.dms.nixosModules.dank-material-shell
        ];
      };

      nixosConfigurations.nixos-vm = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/nixos-vm/configuration.nix
          ({ ... }: {
            nixpkgs.overlays = vmOverlays;
          })
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.matt = import ./home/matt/home.nix;
            home-manager.extraSpecialArgs = { inherit inputs; isVM = true; };
            home-manager.backupFileExtension = "backup";
          }
          inputs.dms.nixosModules.dank-material-shell
        ];
      };

      # Formatter for `nix fmt`
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixpkgs-fmt;
    };
}
