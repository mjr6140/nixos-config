final: prev:
{
  # Temporary: picosvg tests fail on this nixpkgs snapshot.
  python3Packages = prev.python3Packages.overrideScope (_pyFinal: _pyPrev: {
    picosvg = _pyPrev.picosvg.overridePythonAttrs (_: {
      doCheck = false;
      doInstallCheck = false;
    });
  });

  # Temporary: khal docs fail to build with current sphinx stack.
  khal = prev.khal.overrideAttrs (old: {
    nativeBuildInputs = builtins.filter
      (pkg:
        pkg != prev.sphinxHook
        && pkg != prev.python3Packages.sphinx-rtd-theme
        && pkg != prev.python3Packages.sphinxcontrib-newsfeed)
      (old.nativeBuildInputs or [ ]);
    sphinxBuilders = [ ];
    postInstall = (old.postInstall or "") + ''
      mkdir -p "$doc" "$man"
    '';
  });
}
