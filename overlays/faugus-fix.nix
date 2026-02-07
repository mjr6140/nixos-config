final: prev: {
  faugus-launcher = prev.faugus-launcher.overrideAttrs (old: {
    # Add makeWrapper if not already present
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.makeWrapper ];
    
    # Wrap the program to ensure PYTHONPATH includes the faugus module
    # We use --prefix to append to any existing python path
    postFixup = (old.postFixup or "") + ''
      wrapProgram $out/bin/faugus-launcher \
        --prefix PYTHONPATH : "$out/lib/${prev.python3.libPrefix}/site-packages"
    '';
  });
}
