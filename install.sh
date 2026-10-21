#!/usr/bin/env bash
# Runs the Monolith installer from this clone. See install/install.sh.
exec bash "$(dirname "$(realpath "$0")")/install/install.sh" "$@"
