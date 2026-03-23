let
  matt = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBlo4CgrsAdGMbal1HgyaUF8lFYol6DmXZgskdxFt776 mjr6140@gmail.com";
  nixosFileserverVm = "age1s6jpfp27965s6hdvx8qepkruancmr4zq4ncyhdtg468392uyd5tsksmykp";
in
{
  "snapraid-healthchecks.env.age".publicKeys = [ matt nixosFileserverVm ];
}
