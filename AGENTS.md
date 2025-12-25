# Repository Guidelines

## Project Structure & Module Organization
- `flake.nix` and `flake.lock` define inputs/outputs and pin versions.
- `hosts/` contains host-specific NixOS configs (e.g., `hosts/nixos-desktop/`).
- `modules/` holds shared system modules; start in `modules/README.md`.
- `home/` contains Home Manager configs (user-level packages and dotfiles).
- `overlays/` carries package overrides/patches; `docs/` holds supporting guides.

## Build, Test, and Development Commands
- `sudo nixos-rebuild switch --flake .#nixos-desktop` apply the desktop config.
- `sudo nixos-rebuild test --flake .#nixos-desktop` validate without switching.
- `sudo nixos-rebuild build --flake .#nixos-desktop` build only (no activation).
- `nix flake update` refresh inputs; follow with a rebuild.
- `nix flake check` run flake checks for basic validation.
- `nix fmt` format Nix files using `nixpkgs-fmt`.

## Coding Style & Naming Conventions
- Nix files are formatted with `nix fmt` (do not hand-format).
- Keep module names descriptive and lowercase (e.g., `desktop.nix`, `packages.nix`).
- Host directories match hostnames (e.g., `hosts/nixos-vm/`).
- Prefer small, focused modules and document non-obvious options inline.

## Nix Syntax & Idioms (please follow)
- Target modern Nix (2.18+) and nixpkgs patterns; use `lib.*` helpers when appropriate.
- Prefer `lib.mkIf`, `lib.mkMerge`, `lib.mkDefault`, `lib.optional`, `lib.optionals`, `lib.optionalAttrs`.
- Prefer `lib.getExe` and `lib.getExe'` over hard-coded `/bin` paths.
- Use `pkgs.callPackage` for local packages; avoid `import ./file.nix { inherit pkgs; }` when `callPackage` fits.
- Use `lib.recursiveUpdate` or `lib.mkMerge` instead of manual deep attribute updates.
- Prefer `./.` or `builtins.path` for local sources; avoid deprecated `builtins.filterSource` patterns unless needed.
- If unsure, ask a clarifying question before writing non-trivial Nix.

Examples (bad -> good):
```nix
# bad
foo = import ./foo.nix { inherit pkgs; };
# good
foo = pkgs.callPackage ./foo.nix {};

# bad
ExecStart = "/run/current-system/sw/bin/rg";
# good
ExecStart = lib.getExe pkgs.ripgrep;

# bad
attrs = attrs // { nested = (attrs.nested or {}) // { a = 1; }; };
# good
attrs = lib.recursiveUpdate attrs { nested.a = 1; };
```

## Testing Guidelines
- There is no dedicated test suite; validation is via `nix flake check` and
  `nixos-rebuild test`.
- For VM validation, use `sudo nixos-rebuild switch --flake .#nixos-vm`.
- When adding packages or modules, rebuild the relevant host to confirm.

## Commit & Pull Request Guidelines
- Commit messages follow Conventional Commits (`feat:`, `fix:`, `chore:`,
  `refactor:`); keep the subject lowercase and specific.
- PRs should describe the target host(s), list commands run, and note any
  hardware assumptions (e.g., Nvidia, Btrfs layout).
- If a change affects user-level config, mention the `home/` files touched.

## Security & Configuration Tips
- Do not commit secrets or private keys; use `home/` for user-specific settings.
- Hardware configs live under `hosts/<name>/hardware-configuration.nix`; keep
  machine-specific paths isolated there.
