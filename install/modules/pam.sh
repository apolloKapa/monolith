#!/usr/bin/env bash
# PAM service the lock screen authenticates against.

setup_pam_service() {
    local pam_dir="/etc/pam.d"
    local target="$pam_dir/monolith"
    local base=""

    [ -d "$pam_dir" ] || return 0
    [ -e /etc/NIXOS ] && return 0

    for candidate in system-auth login; do
        if [ -f "$pam_dir/$candidate" ]; then
            base="$candidate"
            break
        fi
    done
    [ -n "$base" ] || return 0

    local content=""
    if ! grep -qs "pam_fprintd" "$pam_dir/$base"; then
        content+="-auth       sufficient   pam_fprintd.so"$'\n'
    fi
    content+="auth        include      $base"$'\n'
    content+="account     include      $base"$'\n'

    if [ -f "$target" ] && [ "$(cat "$target" 2>/dev/null)" = "${content%$'\n'}" ]; then
        return 0
    fi

    printf '%s' "$content" | sudo tee "$target" >/dev/null 2>&1 || true
    sudo chmod 644 "$target" 2>/dev/null || true
}

