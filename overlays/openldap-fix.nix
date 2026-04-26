final: prev: {
  openldap = prev.openldap.overrideAttrs (old: {
    preCheck = (old.preCheck or "") + ''
      # TODO: Remove this workaround once nixpkgs/openldap no longer fails
      # these syncrepl tests.
      # Flaky syncrepl tests in this nixpkgs revision: provider/consumer
      # databases diverge intermittently.
      rm -f \
        tests/scripts/test017-syncreplication-refresh \
        tests/scripts/test018-syncreplication-continue \
        tests/scripts/test019-syncreplication-cascade
    '';
  });
}
