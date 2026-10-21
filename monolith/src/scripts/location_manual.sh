#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/config.sh"

lat="$1"
lon="$2"

if [[ -z "$lat" || -z "$lon" ]]; then
    exit 1
fi

now=$(date +%s)
# usage: location_manual.sh <lat> <lon> [city name]
# No reverse geocoding: the coordinates stay between you and the weather service.
city="${3:-$(LC_ALL=C printf '%.2f, %.2f' "$lat" "$lon")}"
country="Unknown"
code="Unknown"
region="Unknown"

tz_req="$(curl -s --max-time 10 "https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&timezone=auto")"
tz="$(echo "$tz_req" | jq -r '.timezone // "UTC"')"

json="$(jq -n \
    --arg lat "$lat" \
    --arg lon "$lon" \
    --arg city "$city" \
    --arg region "$region" \
    --arg country "$country" \
    --arg code "$code" \
    --arg tz "$tz" \
    --argjson ts "$now" \
    '{
        latitude: ($lat|tonumber),
        longitude: ($lon|tonumber),
        city: $city,
        region: $region,
        country_name: $country,
        country_code: $code,
        timezone: $tz,
        source: "manual",
        updated_at: $ts
    }')"

gen="$(get_setting "general" '{}')"
updated="$(echo "$gen" | jq --argjson loc "$json" '.location = $loc')"
set_setting "general" "$updated"
"$(dirname "$(realpath "${BASH_SOURCE[0]}")")/weather.sh" --getdata >/dev/null 2>&1 &
