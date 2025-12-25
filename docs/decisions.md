# Design Decisions & Technical Rationale

This document tracks the "Why" behind the configuration choices in this NixOS setup.

## Filesystem: Btrfs
- **Decision**: Use Btrfs with a "flat" subvolume layout (`@`, `@home`, `@nix`, `@log`).
- **Rationale**: 
    - **Snapshots**: Enables easy rollbacks and data safety.
    - **Granular Rollbacks**: By keeping `/home` and `/nix` separate from the root subvolume, system rollbacks won't affect user data or the package store.
    - **Performance**: Configured with `zstd` compression, `noatime`, and `discard=async` for SSD health and speed.

## "Nix Way" for Development
- **Decision**: Favor per-project environments with `direnv` and flakes over global installs.
- **Rationale**:
    - **Isolation**: Each project has its own dependencies (Go, Rust, Python, Node versions).
    - **Reproducibility**: `flake.nix` in project directories ensures the exact same environment across machines.
    - **Automation**: `direnv` automatically loads shells upon entering a directory.

## Optimized Kernel
- **Decision**:  Latest stable kernel.
- **Rationale**: Better responsiveness and performance optimizations for gaming and desktop use.

## Desktop Environment
- **Decision**: Niri (Wayland) with Dank Material Shell (DMS) on top of GNOME.
- **Rationale**: Provides a modern, tiling Wayland experience while keeping GNOME's robust session management and infrastructure.
