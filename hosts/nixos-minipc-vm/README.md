# Mini PC VM

This host is a disposable VM target for validating the mini PC service-host
configuration before applying it to the real N100 hardware.

It intentionally tracks the server-side mini PC role closely:

- Docker host defaults
- generic Compose stack management
- observability stack
- shared server package set

Current Compose-managed services are defined under `modules/server/stacks/`.
The VM is the place to validate that stack wiring before applying it to the
real mini PC host.

It intentionally does not model N100-specific hardware features like Intel GPU
acceleration. Those stay in the real host config.

## Rebuild

Apply this host config with:

```sh
sudo nixos-rebuild switch --flake .#nixos-minipc-vm
```

For remote rebuilds from another machine, use:

```sh
sudo NIX_SSHOPTS="-i /home/matt/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new" \
  nixos-rebuild switch \
  --flake .#nixos-minipc-vm \
  --target-host matt@192.168.122.7 \
  --sudo
```

## VM Creation

Use the provisioning script to build a bootable QCOW2 from the flake and import
it into libvirt without an installer ISO:

```sh
scripts/create-minipc-vm.sh --recreate
```

Useful options:

```sh
scripts/create-minipc-vm.sh --help
```
