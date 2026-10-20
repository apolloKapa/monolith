{ config, pkgs, inputs, ... }:
{
  home.username    = "apollo";
  home.homeDirectory = "/home/apollo";
  home.stateVersion = "25.05";

  programs.caelestia = {
    enable = true;
    systemd.enable = false;
    cli = {
      enable = true;
    };
  };

  home.sessionVariables = {
    XCURSOR_THEME = "Moga-Purple";
    XCURSOR_SIZE  = "24";
  };

  home.pointerCursor = {
    name    = "Moga-Purple";
    package = pkgs.runCommand "moga-purple-cursor" {} ''
      mkdir -p $out/share/icons
      cp -r ${./Moga-Purple-cursor} $out/share/icons/Moga-Purple
    '';
    size       = 24;
    gtk.enable = true;
  };

  gtk = {
    enable = true;
    cursorTheme = {
      name = "Moga-Purple";
      size = 24;
    };
    iconTheme = {
      name    = "YAMIS";
      package = pkgs.runCommand "yamis-icons" {} ''
        mkdir -p $out/share/icons
        cp -r ${./YAMIS-icons} $out/share/icons/YAMIS
      '';
    };
    theme = {
      name    = "Dracula";
      package = pkgs.dracula-theme;
    };
    gtk4.theme = config.gtk.theme;
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  home.file.".config/cava/config".text = ''
    [color]
    gradient = 1
    gradient_count = 3
    gradient_color_1 = '#a87dd4'
    gradient_color_2 = '#a87dd4'
    gradient_color_3 = '#a87dd4'
  '';

  programs.home-manager.enable = true;
}
