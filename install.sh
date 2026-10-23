#!/usr/bin/env bash
# Installs this repository's color themes only. Does not install/replace the desktop.
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
available=(changli hiyuki emilia furina hotline-miami)

usage() {
  printf 'Usage: bash install.sh <theme|--all|--list>\n'
  printf 'Example: bash install.sh --all\n'
}

case "${1:-}" in
  --help|-h) usage; exit 0 ;;
  --list) printf '%s\n' "${available[@]}"; exit 0 ;;
  --all) selected=("${available[@]}") ;;
  changli|hiyuki|emilia|furina|hotline-miami) selected=("$1") ;;
  *) usage >&2; exit 2 ;;
esac
if [[ $# -ne 1 ]]; then usage >&2; exit 2; fi

if [[ ! -d "$HOME/.config/illogical-impulse" || ! -d "$HOME/.config/quickshell/end4-pC" ]]; then
  cat >&2 <<'MESSAGE'
Base desktop not found. This repository adds themes to an EXISTING installation.
Install end-4's illogical-impulse and pctrade's end4-pC first:
  https://github.com/end-4/dots-hyprland
  https://github.com/pctrade/end4-pC
See README.md for the step-by-step setup. Nothing has been modified.
MESSAGE
  exit 2
fi

schemes_dir="$HOME/.config/illogical-impulse/schemes"
fastfetch_dir="$HOME/.config/fastfetch/themes"
backup_dir="$HOME/.local/share/hyprland-themes/backups/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$schemes_dir" "$fastfetch_dir" "$backup_dir"

copy_with_backup() {
  local from="$1" to="$2" label="$3"
  if [[ -e "$to" ]] && ! cmp -s "$from" "$to"; then
    cp -p -- "$to" "$backup_dir/$label"
    printf 'Backed up: %s\n' "$to"
  fi
  cp -- "$from" "$to"
}

for theme in "${selected[@]}"; do
  copy_with_backup "$repo_dir/end4-pC/$theme.json" "$schemes_dir/$theme.json" "end4-pC-$theme.json"
  copy_with_backup "$repo_dir/fastfetch/$theme.json" "$fastfetch_dir/$theme.json" "fastfetch-$theme.json"
  printf 'Installed: %s\n' "$theme"
done

printf '\nBackups, if needed: %s\n' "$backup_dir"
printf 'Next: open end4-pC Settings > Color scheme and select a theme.\n'
printf 'Fastfetch example: fastfetch --config "$HOME/.config/fastfetch/themes/changli.json"\n'
printf 'No wallpaper, keybind, service or running desktop was changed.\n