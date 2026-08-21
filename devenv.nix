{ pkgs, lib, config, inputs, ... }:

{
  languages.clojure.enable = true;
  languages.ansible.enable = true;
  languages.opentofu.enable = true;
  packages = [
    pkgs.babashka
    pkgs.jet
    pkgs.hcl2json
    pkgs.awscli2 # the R2 backend authenticates through the AWS chain
    pkgs.oci-cli # stop/start drive this directly
  ];
}
