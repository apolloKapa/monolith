{ config, pkgs, inputs, ... }:
{
  imports = [ 
	./hardware-configuration.nix 
	inputs.nix-gaming.nixosModules.pipewireLowLatency
  ];

  environment.systemPackages = with pkgs; [
    inputs.nix-gaming.packages.${pkgs.stdenv.hostPlatform.system}.osu-stable
    brave
    fastfetch
    btop
    hyfetch
    qbittorrent
    kitty
    vscodium
    lutris
    openrgb-with-all-plugins
    mullvad-vpn
    jq
    python3
    prismlauncher
    glib
    unzip
    git
    grimblast
    thunar
    vesktop
    lolcat
    lavat
    tty-clock
    cava
    gvfs
    dosfstools
    qt6Packages.qt6ct
    wl-clipboard
    brightnessctl
    slurp
    grimblast
    swappy
    cliphist
    papirus-icon-theme
  ];

  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-gaming.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
    ];
  };

  programs.thunar = {
    enable = true;
    plugins = with pkgs; [
      thunar-archive-plugin
      thunar-volman
    ];
  };

  services.gvfs.enable = true;
  services.tumbler.enable = true;
  services.udisks2.enable = true;
  services.flatpak.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.blueman.enable = true;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    nssmdns6 = true;  # enable IPv6 mDNS resolution
    ipv4 = true;
    ipv6 = true;
    openFirewall = true;
  };

services.wivrn = {
  enable = true;
  openFirewall = true;
};

  services.hardware.openrgb = {
    enable = true;
    motherboard = "amd";
  };

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.noto
    jetbrains-mono
    udev-gothic-nf
    noto-fonts
    noto-fonts-color-emoji
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 5;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "i2c-dev" "i2c-piix4" ];

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Athens";
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
  ];

hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  programs.uwsm = {
    enable = true;
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME                   = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME           = "nvidia";
    NIXOS_OZONE_WL                      = "1";
    ELECTRON_OZONE_PLATFORM_HINT        = "auto";
    QT_QPA_PLATFORM                     = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    GBM_BACKEND                         = "nvidia-drm";
  };

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.uwsm}/bin/uwsm start hyprland-uwsm.desktop";
        user = "apollo";
      };
    };
  };

  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    lowLatency = {
      enable = true;
      quantum = 128;
      rate = 48000;
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ 
      pkgs.xdg-desktop-portal-hyprland 
      pkgs.xdg-desktop-portal-gtk
    ];
    config.common.default = "*";
  };

  systemd.tmpfiles.rules = [
    "d /home/apollo/.config/caelestia 0755 apollo users -"
  ];

  users.users.apollo = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" "video" "audio" "i2c" ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 5d";
  };

  system.stateVersion = "25.05";
}
