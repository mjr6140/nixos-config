let
  matt = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBlo4CgrsAdGMbal1HgyaUF8lFYol6DmXZgskdxFt776 mjr6140@gmail.com";
  nixosDesktop = "age140dgcxgtm46nz9wcucs25cxm8u8vvk074frp5amqa04d2tewvuqsyeejds";
  nixosFileserverVm = "age1s6jpfp27965s6hdvx8qepkruancmr4zq4ncyhdtg468392uyd5tsksmykp";
  nixosMinipc = "age16fflckqpdspsrfdhuucfn7cjeapdjxm2s5hy3xtwwctjyq9dcf7sp70uzp";
  nixosMinipcVm = "age1lc6jdh73cz0df4c7rxzrjwpw2w2wp4z3j4w60uvufaqa834syvyqmly863";
in
{
  "snapraid-healthchecks.env.age".publicKeys = [ matt nixosFileserverVm ];
  "pihole.env.age".publicKeys = [ matt nixosMinipc nixosMinipcVm ];
  "caddy.env.age".publicKeys = [ matt nixosMinipc nixosMinipcVm ];
  "karakeep.env.age".publicKeys = [ matt nixosMinipc nixosMinipcVm ];
  "gluetun.env.age".publicKeys = [ matt nixosMinipc nixosMinipcVm ];
  "restic-nixos-desktop.env.age".publicKeys = [ matt nixosDesktop ];
  "restic-nixos-desktop-ssh.age".publicKeys = [ matt nixosDesktop ];
  "restic-nixos-minipc.env.age".publicKeys = [ matt nixosMinipc ];
  "restic-nixos-minipc-vps.env.age".publicKeys = [ matt nixosMinipc ];
  "restic-nixos-minipc-vps-ssh.age".publicKeys = [ matt nixosMinipc ];
}
