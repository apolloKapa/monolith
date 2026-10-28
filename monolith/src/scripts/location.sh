#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/config.sh"

export LC_ALL=C

VERBOSE=false
FORCE_REFRESH=false

for arg in "$@"; do
    if [[ "$arg" == "--verbose" || "$arg" == "-v" ]]; then
        VERBOSE=true
    elif [[ "$arg" == "--refresh" || "$arg" == "-r" ]]; then
        FORCE_REFRESH=true
    fi
done

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "\e[1;34m[LOCATION-DEBUG]\e[0m $1" >&2
    fi
}

get_existing_location() {
    local gen
    gen="$(get_setting "general" '{}')"
    echo "$gen" | jq -c '.location // empty' 2>/dev/null
}

save_location() {
    local loc_data="$1"
    local gen
    gen="$(get_setting "general" '{}')"
    local updated
    updated="$(echo "$gen" | jq --argjson loc "$loc_data" '.location = $loc')"
    set_setting "general" "$updated"
    "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/weather.sh" --getdata >/dev/null 2>&1 &
}

# Monolith never looks you up by IP. The location only comes from what you set
# (Settings -> General, or location_manual.sh <lat> <lon>). Anything that would
# identify you (IP, ISP, postcode) is stripped if an old config still has it.
PRIVATE_FIELDS='del(.ip, .asn, .org, .postal, .currency, .languages, .utc_offset)'

resolve_location() {
    local existing
    existing="$(get_existing_location)"

    # a location you set always has the time you set it. One without (updated_at 0) came with
    # Monolith's old default settings, which carried the author's location: never use it
    if [[ -n "$existing" && "$existing" != "null" ]] \
        && echo "$existing" | jq -e '(.updated_at // 0) == 0' >/dev/null 2>&1; then
        log_debug "Removing a location that came with the default settings."
        local gen
        gen="$(get_setting "general" '{}')"
        set_setting "general" "$(echo "$gen" | jq 'del(.location)')"
        existing=""
    fi

    if [[ -n "$existing" && "$existing" != "null" ]]; then
        local clean
        clean="$(echo "$existing" | jq -c "$PRIVATE_FIELDS")"
        if [[ "$clean" != "$(echo "$existing" | jq -c .)" ]]; then
            log_debug "Removing identifying fields from stored location."
            save_location "$clean"
        fi
        echo "$clean"
        return
    fi

    log_debug "No location set. Set one in Settings to get weather."
    echo '{"latitude": 0.0, "longitude": 0.0, "city": "Unknown", "region": "Unknown", "country_name": "Unknown", "timezone": "UTC", "updated_at": 0}'
}

resolve_location
