# Nvidia suspend/resume fixes for desktop systems
# Addresses the double-suspend issue and screen blanking after resume in GNOME
{ config, pkgs, lib, ... }:

{
  # The kernel parameters needed for nvidia power management to work properly
  boot.kernelParams = [ 
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    "nvidia.NVreg_TemporaryFilePath=/var/tmp"
  ];

  # Fix for double-suspend: The issue is that GNOME Power Manager
  # checks idle time after resume and immediately suspends again if
  # the idle timer hasn't been reset properly. This systemd service
  # adds a delay after resume to prevent this race condition.
  systemd.services.gnome-resume-delay = {
    description = "Delay to prevent GNOME double-suspend after resume";
    after = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
    wantedBy = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      # Hold a systemd inhibitor lock to prevent immediate re-suspend
      # This gives GNOME time to properly detect user activity
      ExecStart = pkgs.writeShellScript "prevent-double-suspend" ''
        # Wait for the system to fully resume
        ${pkgs.coreutils}/bin/sleep 2
        
        # Hold a systemd inhibitor lock to prevent re-suspend during the critical window
        ${pkgs.systemd}/bin/systemd-inhibit --what=idle:sleep --who="Resume Guard" \
          --why="Preventing double-suspend after resume" \
          ${pkgs.coreutils}/bin/sleep 5
      '';
      TimeoutStartSec = "15s";
    };
  };

  # Fix for screen blanking after resume:
  # GNOME's power management triggers screen blanking shortly after resume.
  # We need to send signals continuously for a longer period to cover the time
  # when the user is unlocking the screen.
  systemd.services.gnome-screen-resume-fix = {
    description = "Prevent screen blanking immediately after resume";
    after = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" "display-manager.service" ];
    wantedBy = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "fix-screen-blank-resume" ''
        # Wait for GNOME to initialize
        ${pkgs.coreutils}/bin/sleep 3
        
        # For each active graphical session, continuously send activity signals
        # for a full 30 seconds to cover the unlock period and beyond
        for session in $(${pkgs.systemd}/bin/loginctl list-sessions --no-legend | ${pkgs.gawk}/bin/awk '{print $1}'); do
          SESSION_USER=$(${pkgs.systemd}/bin/loginctl show-session $session -p Name --value 2>/dev/null)
          SESSION_TYPE=$(${pkgs.systemd}/bin/loginctl show-session $session -p Type --value 2>/dev/null)
          
          # Only process graphical sessions
          if [ "$SESSION_TYPE" = "wayland" ] || [ "$SESSION_TYPE" = "x11" ]; then
            USER_ID=$(id -u "$SESSION_USER" 2>/dev/null)
            
            if [ -n "$USER_ID" ]; then
              export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus"
              
              # Send activity signals every 2 seconds for 30 seconds
              # This covers: resume -> lock screen -> user unlocking -> post-unlock period
              for i in {1..15}; do
                ${pkgs.sudo}/bin/sudo -u "$SESSION_USER" \
                  DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
                  ${pkgs.dbus}/bin/dbus-send --session --dest=org.gnome.ScreenSaver \
                  /org/gnome/ScreenSaver org.gnome.ScreenSaver.SimulateUserActivity 2>/dev/null || true
                
                ${pkgs.sudo}/bin/sudo -u "$SESSION_USER" \
                  DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
                  ${pkgs.dbus}/bin/dbus-send --session --dest=org.gnome.Mutter.IdleMonitor \
                  /org/gnome/Mutter/IdleMonitor/Core org.gnome.Mutter.IdleMonitor.ResetIdletime 2>/dev/null || true
                
                ${pkgs.coreutils}/bin/sleep 2
              done
            fi
          fi
        done
      '';
      TimeoutStartSec = "60s";
    };
  };
}
