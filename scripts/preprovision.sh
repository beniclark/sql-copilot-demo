#!/usr/bin/env sh
set -eu

get_val() { azd env get-values --output json 2>/dev/null | jq -r --arg k "$1" '.[$k] // empty'; }
set_env() { azd env set "$1" "$2" >/dev/null; }
set_secret() { azd env set-secret "$1" "$2" >/dev/null; }

if [ -z "$(get_val PRESENTER_IP)" ]; then
  ip=$(curl -s https://api.ipify.org || true)
  if [ -z "$ip" ]; then printf 'Enter presenter public IPv4: '; read -r ip; fi
  case "$ip" in *"/"*) ;; *) ip="$ip/32";; esac
  set_env PRESENTER_IP "$ip"
fi

if [ -z "$(get_val ENTRA_ADMIN_UPN)" ]; then
  upn=$(az account show --query user.name -o tsv 2>/dev/null || true)
  if [ -z "$upn" ]; then printf 'Entra admin UPN: '; read -r upn; fi
  set_env ENTRA_ADMIN_UPN "$upn"
fi

gen_pw() { printf '%s' "$(LC_ALL=C tr -dc 'A-Za-z0-9!@#%^&*?' </dev/urandom | head -c 20)Aa1!"; }

[ -z "$(get_val SQL_ADMIN_PASSWORD)" ] && set_secret SQL_ADMIN_PASSWORD "$(gen_pw)"
[ -z "$(get_val VM_ADMIN_PASSWORD)"  ] && set_secret VM_ADMIN_PASSWORD  "$(gen_pw)"

echo "Preprovision hook complete."
