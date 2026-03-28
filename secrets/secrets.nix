let
  matt = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBlo4CgrsAdGMbal1HgyaUF8lFYol6DmXZgskdxFt776 mjr6140@gmail.com";
  nixosFileserverVm = "age1s6jpfp27965s6hdvx8qepkruancmr4zq4ncyhdtg468392uyd5tsksmykp";
  nixosMinipcVm = "age1lc6jdh73cz0df4c7rxzrjwpw2w2wp4z3j4w60uvufaqa834syvyqmly863";
in
{
  "snapraid-healthchecks.env.age".publicKeys = [ matt nixosFileserverVm ];
  "pihole.env.age".publicKeys = [ matt nixosMinipcVm ];
  "caddy.env.age".publicKeys = [ matt nixosMinipcVm ];
}
