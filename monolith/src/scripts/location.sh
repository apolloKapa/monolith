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

# Where you are, for the weather, night light and clock. A location you set (Settings -> General,
# or location_manual.sh <lat> <lon>) is kept as it is. Without one, Monolith works it out from
# your internet connection (an IP lookup over HTTPS: ipapi.co, then ipwho.is) and keeps only the
# city, region, country, timezone and coordinates rounded to about 1 km: never the IP, provider or
# postcode. A detected location is looked up again after AUTO_MAX_AGE (a laptop moves around);
# --detect looks it up now (the Detect button) and replaces even one you set.
PRIVATE_FIELDS='del(.ip, .asn, .org, .postal, .zip, .currency, .languages, .utc_offset)'
AUTO_MAX_AGE=$((6 * 3600))
DETECT=false
for arg in "$@"; do [[ "$arg" == "--detect" ]] && DETECT=true; done

# provider JSON -> Monolith's location (null when the reply isn't usable)
SHAPE='def r2: ((. * 100 | round) / 100);
    if (.lat | type) == "number" and (.lon | type) == "number" then
    { latitude: (.lat | r2), longitude: (.lon | r2), city: (.city // "Unknown"), region: (.region // ""),
      country_name: (.country // ""), country_code: (.code // ""), timezone: (.tz // "UTC"),
      source: "auto", updated_at: now | floor } else null end'

detect_location() {
    local resp loc
    resp="$(curl -fsS --max-time 6 -H "User-Agent: monolith-location/1.0" "https://ipapi.co/json/" 2>/dev/null)"
    loc="$(echo "$resp" | jq -c "{lat: .latitude, lon: .longitude, city, region, country: .country_name, code: .country_code, tz: .timezone} | $SHAPE" 2>/dev/null)"
    if [[ -z "$loc" || "$loc" == "null" ]]; then
        log_debug "ipapi.co didn't answer, trying ipwho.is"
        resp="$(curl -fsS --max-time 6 "https://ipwho.is/" 2>/dev/null)"
        loc="$(echo "$resp" | jq -c "if .success == false then null else {lat: .latitude, lon: .longitude, city, region, country, code: .country_code, tz: .timezone.id} | $SHAPE end" 2>/dev/null)"
    fi
    [[ -n "$loc" && "$loc" != "null" ]] && echo "$loc"
}

resolve_location() {
    local existing
    existing="$(get_existing_location)"

    # a location without the time it was set came with Monolith's old default settings, which
    # carried the author's location: never use it
    if [[ -n "$existing" && "$existing" != "null" ]] \
        && echo "$existing" | jq -e '(.updated_at // 0) == 0' >/dev/null 2>&1; then
        log_debug "Removing a location that came with the default settings."
        local gen
        gen="$(get_setting "general" '{}')"
        set_setting "general" "$(echo "$gen" | jq 'del(.location)')"
        existing=""
    fi

    local want_detect=$DETECT
    if [[ -z "$existing" || "$existing" == "null" ]]; then
        want_detect=true
    elif echo "$existing" | jq -e --argjson max "$AUTO_MAX_AGE" '.source == "auto" and (now - (.updated_at // 0)) > $max' >/dev/null 2>&1; then
        want_detect=true
    fi

    if [[ "$want_detect" == "true" ]]; then
        local found
        found="$(detect_location)"
        if [[ -n "$found" ]]; then
            log_debug "Detected: $found"
            save_location "$found"
            echo "$found"
            return
        fi
        log_debug "Couldn't detect the location (offline?)."
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

    log_debug "No location: set one in Settings to get weather."
    echo '{"latitude": 0.0, "longitude": 0.0, "city": "Unknown", "region": "Unknown", "country_name": "Unknown", "timezone": "UTC", "updated_at": 0}'
}

resolve_location
