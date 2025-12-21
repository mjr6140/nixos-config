final: prev: {
  rusty-path-of-building = prev.rusty-path-of-building.overrideAttrs (oldAttrs: {
    postFixup = (prev.lib.replaceStrings 
      [ "wrapProgram $out/bin/rusty-path-of-building" ]
      [ 
        ''
          wrapProgram $out/bin/rusty-path-of-building \
            --set QT_QPA_PLATFORM xcb \
            --set WGPU_BACKEND gl \
            --set LIBGL_ALWAYS_SOFTWARE 1 \
            --set MESA_LOADER_DRIVER_OVERRIDE llvmpipe \
            --set GALLIUM_DRIVER llvmpipe \
            --set __GLX_VENDOR_LIBRARY_NAME mesa \
            --set MESA_GL_VERSION_OVERRIDE 4.5 \
            --unset VK_DRIVER_FILES''
      ] 
      (oldAttrs.postFixup or "")
    );
  });
}
