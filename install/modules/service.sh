#!/usr/bin/env bash

detect_init_system() {
    if [[ -d /run/systemd/system ]] || command -v systemctl &>/dev/null; then
        echo "systemd"
    elif command -v openrc-init &>/dev/null || [[ -d /run/openrc ]]; then
        echo "openrc"
    elif command -v dinit &>/dev/null || [[ -d /etc/dinit.d ]]; then
        echo "dinit"
    elif command -v runit &>/dev/null || [[ -d /run/runit ]]; then
        echo "runit"
    elif command -v s6-svscan &>/dev/null; then
        echo "s6"
    else
        echo "generic"
    fi
}

# (a third argument "later": set to start at boot, not started now. The login screen is: started
# in the middle of the install it took the screen from the installer, which went on unseen)
enable_system_service() {
    local svc="$1"
    local init_sys="$2"
    local now=true
    [ "$3" = later ] && now=false

    case "$init_sys" in
        systemd)
            if [ "$now" = true ]; then
                sudo systemctl enable --now "$svc.service" 2>/dev/null || sudo systemctl enable -f "$svc.service" 2>/dev/null || sudo systemctl enable "$svc.service" 2>/dev/null || true
            else
                sudo systemctl enable "$svc.service" 2>/dev/null || sudo systemctl enable -f "$svc.service" 2>/dev/null || true
            fi
            ;;
        openrc)
            if [ ! -e "/etc/init.d/$svc" ] && [ -e /etc/init.d/display-manager ] && [ -f "/usr/bin/$svc" ]; then
                # Gentoo has no per-display-manager service: it's "display-manager", told which one
                # to run in /etc/conf.d/display-manager
                if grep -q '^DISPLAYMANAGER=' /etc/conf.d/display-manager 2>/dev/null; then
                    sudo sed -i "s/^DISPLAYMANAGER=.*/DISPLAYMANAGER=\"$svc\"/" /etc/conf.d/display-manager
                else
                    echo "DISPLAYMANAGER=\"$svc\"" | sudo tee -a /etc/conf.d/display-manager >/dev/null
                fi
                svc=display-manager
            fi
            sudo rc-update add "$svc" default 2>/dev/null || true
            [ "$now" = true ] && { sudo rc-service "$svc" start 2>/dev/null || true; }
            ;;
        dinit)
            if [ "$now" = true ]; then
                sudo dinitctl enable "$svc" 2>/dev/null || sudo dinitctl start "$svc" 2>/dev/null || true
            else
                sudo dinitctl enable --from boot "$svc" 2>/dev/null || true
            fi
            ;;
        runit)
            if [ -d "/etc/sv/$svc" ]; then
                sudo ln -sf "/etc/sv/$svc" /var/service/ 2>/dev/null || true
            fi
            ;;
        s6)
            sudo s6-rc-bundle-update -b add default "$svc" 2>/dev/null || true
            ;;
        *)
            true
            ;;
    esac
}

disable_system_service() {
    local svc="$1"
    local init_sys="$2"

    case "$init_sys" in
        systemd)
            sudo systemctl disable --now "$svc.service" 2>/dev/null || sudo systemctl disable "$svc.service" 2>/dev/null || sudo systemctl disable "$svc" 2>/dev/null || true
            ;;
        openrc)
            sudo rc-service "$svc" stop 2>/dev/null || true
            sudo rc-update del "$svc" default 2>/dev/null || true
            ;;
        dinit)
            sudo dinitctl stop "$svc" 2>/dev/null || true
            sudo dinitctl disable "$svc" 2>/dev/null || true
            ;;
        runit)
            if [ -L "/var/service/$svc" ] || [ -d "/var/service/$svc" ]; then
                sudo rm -f "/var/service/$svc" 2>/dev/null || true
            fi
            ;;
        s6)
            sudo s6-rc-bundle-update -b del default "$svc" 2>/dev/null || true
            ;;
        *)
            true
            ;;
    esac
}

enable_user_service() {
    local svc="$1"
    local init_sys="$2"

    case "$init_sys" in
        systemd)
            systemctl --user daemon-reload 2>/dev/null || true
            systemctl --user enable --now "$svc.service" 2>/dev/null || systemctl --user enable "$svc.service" 2>/dev/null || true
            ;;
        dinit)
            dinitctl --user enable "$svc" 2>/dev/null || dinitctl --user start "$svc" 2>/dev/null || true
            ;;
        *)
            true
            ;;
    esac
}

setup_services() {
    local init_sys
    init_sys=$(detect_init_system)

    if [[ "$init_sys" == "systemd" ]]; then
        systemctl --user enable pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true
        systemctl --user start pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true
    fi

    # OpenRC (Gentoo): elogind (the seat niri and the login screen run on, and who may suspend
    # or shut down) and D-Bus aren't in any runlevel on a fresh install; Gentoo's guides say to add
    # them. Only when they're installed (someone on seatd has no elogind)
    if [ "$init_sys" = openrc ]; then
        if [ -e /etc/init.d/elogind ] && ! rc-update show 2>/dev/null | grep -qE '^[[:space:]]*elogind[[:space:]]'; then
            sudo rc-update add elogind boot 2>/dev/null || true
        fi
        if [ -e /etc/init.d/dbus ] && ! rc-update show 2>/dev/null | grep -qE '^[[:space:]]*dbus[[:space:]]'; then
            sudo rc-update add dbus default 2>/dev/null || true
            sudo rc-service dbus start 2>/dev/null || true
        fi
    fi

    enable_user_service "easyeffects" "$init_sys"
    # NetworkManager next to another network service (OpenRC: dhcpcd, or netifrc's net.eth0 and
    # the like) and the two fight over the connection. Not started now then: it takes over at the
    # next boot, once you've taken the other one out (said how)
    local others=""
    # (iwd isn't one: NetworkManager can use it for Wi-Fi. NetworkManager already set to start:
    # sorted out before)
    if [ "$init_sys" = openrc ] && ! rc-update show default 2>/dev/null | grep -qE '^[[:space:]]*NetworkManager[[:space:]]'; then
        others=$(rc-update show default 2>/dev/null | awk '{print $1}' | grep -E '^(dhcpcd|net\.[^l].*|net\.l[^o].*|connman|wpa_supplicant)$' | tr '\n' ' ')
    fi
    if [ -n "$others" ]; then
        enable_system_service "NetworkManager" "$init_sys" later
        echo -e "  \e[33m[ WARN ]\e[0m NetworkManager (the network menu's) is set to start at boot, alongside ${others% }."
        echo -e "         Two network services fight over the connection: take the other one out with"
        local o
        for o in $others; do echo -e "         \e[1msudo rc-update del $o default\e[0m"; done
        echo -e "         (NetworkManager then keeps you online)"
    else
        enable_system_service "NetworkManager" "$init_sys"
    fi
    enable_system_service "power-profiles-daemon" "$init_sys"
    # Bluetooth (the Bluetooth menu): bluez is installed, but its service is off by default on most
    # systems. Only on a PC with a Bluetooth adapter
    if compgen -G "/sys/class/bluetooth/*" >/dev/null; then
        enable_system_service "bluetooth" "$init_sys"
    fi
}
