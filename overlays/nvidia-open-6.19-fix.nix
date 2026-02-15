final: prev: {
  linuxPackages_latest = prev.linuxPackages_latest.extend (_self: super: {
    nvidiaPackages =
      super.nvidiaPackages
      // {
        beta = super.nvidiaPackages.beta.overrideAttrs (old: {
          passthru =
            (old.passthru or {})
            // {
              open = (old.passthru.open or super.nvidiaPackages.beta.open).overrideAttrs (oldOpen: {
                patches =
                  (oldOpen.patches or [])
                  ++ [ ./patches/nvidia-open-6.19-compat.patch ];
              });
            };
        });
        latest = super.nvidiaPackages.latest.overrideAttrs (old: {
          passthru =
            (old.passthru or {})
            // {
              open = (old.passthru.open or super.nvidiaPackages.latest.open).overrideAttrs (oldOpen: {
                patches =
                  (oldOpen.patches or [])
                  ++ [ ./patches/nvidia-open-6.19-compat.patch ];
              });
            };
        });
      };
  });
}
