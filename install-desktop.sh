#!/usr/bin/env bash
# Hyprland-Themes — desktop customization installer
# No root or package installation. Existing end-4/illogical-impulse is required.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:---help}"
PATCH="$ROOT/overrides/end4-pC-custom.patch"
BASE_FILE="$ROOT/overrides/end4-pC-base-commit.txt"
EXTRAS="$ROOT/overrides/end4-pC"
QS="$HOME/.config/quickshell/end4-pC"
II="$HOME/.config/illogical-impulse"
BACKUP_ROOT="$HOME/.local/share/Hyprland-Themes/backups"

usage() {
  cat <<'HELP'
Usage: bash install-desktop.sh --prepare-base | --check | --apply

--prepare-base: clone and pin end4-pC if it is NOT installed yet.
--check: read-only validation. Does NOT install or modify your desktop.
--apply: requires confirmation; backs up your existing configuration before
         copying public dotfiles and applying the end4-pC patch.

Requirements:
  Arch Linux with end-4 illogical-impulse and pctrade end4-pC already installed.
  See README.md for the original upstream setup procedure.
  Your end4-pC checkout must be clean and at the patch's pinned commit.

Private Controller Mode files are NOT bundled, installed or modified.
Wallpaper images are NOT bundled. Services are copied but NOT enabled.
After --apply, opt in with: systemctl --user enable --now end4-wallpaper-theme.path
HELP
}

case "$MODE" in
  --prepare-base|--check|--apply) ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
[[ $# -eq 1 ]] || { usage >&2; exit 2; }

error() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
note() { printf '%s\n' "$*"; }

[[ -f "$PATCH" && -s "$PATCH" ]] || error "Missing end4-pC patch: $PATCH"
[[ -f "$BASE_FILE" ]] || error "Missing base commit file: $BASE_FILE"
[[ -d "$EXTRAS" ]] || error "Missing additional QML files: $EXTRAS"
[[ -d "$ROOT/dots/.config/hypr/hyprland" ]] || error 'Missing exported Hyprland configuration.'
[[ -f "$ROOT/install.sh" ]] || error 'Missing theme installer.'
[[ -d "$II" ]] || error "Original illogical-impulse not found at $II. Install upstream first."

for program in git bash python3; do
  command -v "$program" >/dev/null 2>&1 || error "Missing command: $program"
done

BASE="$(tr -d '\r\n\t ' < "$BASE_FILE")"
[[ "$BASE" =~ ^[0-9a-fA-F]{40}$ ]] || error 'Base commit file does not contain a full 40-digit SHA.'

if [[ "$MODE" == '--prepare-base' ]]; then
  [[ ! -e "$QS" && ! -L "$QS" ]] || error "Destination already exists; refusing to replace it: $QS"
  parent="$(dirname -- "$QS")"
  mkdir -p -- "$parent"
  temporary="$(mktemp -d "$parent/.end4-pC-install.XXXXXXXX")"
  trap 'rm -rf -- "$temporary"' EXIT
  git clone --quiet "${END4_PC_SOURCE:-https://github.com/pctrade/end4-pC.git}" "$temporary/end4-pC"
  git -C "$temporary/end4-pC" cat-file -e "${BASE}^{commit}" || error 'Pinned commit unavailable in upstream clone.'
  git -C "$temporary/end4-pC" checkout --quiet --detach "$BASE"
  mv -- "$temporary/end4-pC" "$QS"
  note "Pinned end4-pC prepared at: $QS"
  note 'Next: bash install-desktop.sh --check'
  exit 0
fi

[[ -d "$QS/.git" || -f "$QS/.git" ]] || error "end4-pC Git checkout not found at $QS. Run --prepare-base or follow upstream instructions."
for theme in changli hiyuki emilia furina hotline-miami; do
  [[ -f "$ROOT/end4-pC/$theme.json" && -f "$ROOT/fastfetch/$theme.json" ]] || error "Missing color theme: $theme"
done

# Refuse to publish or install private paths accidentally copied to the public bundle.
if command -v rg >/dev/null 2>&1; then
  if rg --hidden -l -i --glob '!**/.git/**' \
    'controller-mode|controller-steam|/home/pedro|/run/media/pedro|BEGIN [A-Z ]*PRIVATE KEY' \
    "$ROOT/dots" "$ROOT/overrides" >/dev/null; then
    error 'Private path or Controller Mode reference detected in public dotfiles/overrides. Review the export first.'
  fi
fi

# Prevent following unexpected symlinks from the exported dotfiles.
if [[ -n "$(find "$ROOT/dots" "$EXTRAS" -type l -print -quit)" ]]; then
  error 'Export contains symlinks; review them before installing.'
fi

CURRENT="$(git -C "$QS" rev-parse HEAD)" || error 'Could not read end4-pC HEAD.'
note "Patch base:  $BASE"
note "Desktop HEAD: $CURRENT"
git -C "$QS" cat-file -e "${BASE}^{commit}" || error 'Pinned upstream base commit not available in the local end4-pC Git history.'

# Dry-run against a pristine, detached work copy. Do not test on (or modify)
# the user's active customized Quickshell checkout.
STAGE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/hyprland-themes-check.XXXXXXXX")"
install_started=0
backup=''
on_exit() {
  local code=$?
  trap - EXIT
  rm -rf -- "$STAGE_ROOT"
  if [[ "$code" -ne 0 && "$install_started" -eq 1 ]]; then
    note 'Install failed. Attempting to restore the original configuration...'
    set +e
    if [[ -f "$backup/created-files.bin" ]]; then
      while IFS= read -r -d '' installed_file; do
        case "$installed_file" in "$HOME"/.config/*|"$HOME"/.local/bin/*) rm -f -- "$installed_file" ;; esac
      done < "$backup/created-files.bin"
    fi
    if [[ -d "$backup/originals" ]]; then
      while IFS= read -r -d '' original_file; do
        relative="${original_file#"$backup/originals/"}"
        restored="$HOME/$relative"
        mkdir -p -- "$(dirname -- "$restored")"
        cp -a -- "$original_file" "$restored"
      done < <(find "$backup/originals" -type f -print0)
    fi
    if [[ -d "$backup/quickshell/end4-pC" ]]; then
      mv -- "$QS" "$backup/failed-end4-pC" && cp -a -- "$backup/quickshell/end4-pC" "$QS"
    fi
    note "Recovery attempted; inspect backup: $backup"
  fi
  exit "$code"
}
trap on_exit EXIT
STAGE_QS="$STAGE_ROOT/end4-pC"
git clone --quiet --no-hardlinks -- "$QS" "$STAGE_QS"
git -C "$STAGE_QS" checkout --quiet --detach "$BASE"
git -C "$STAGE_QS" apply --check "$PATCH" || error 'Patch does not apply to pinned upstream base.'
git -C "$STAGE_QS" apply "$PATCH"

EXTRA_FILES=(
  'modules/ii/settings/DashboardCheatsheetPage.qml'
  'modules/ii/wallpaperSelector/AnimatedWallpaperGrid.qml'
  'scripts/animated-picker.py'
  'services/WallpaperLayouts.qml'
)
for rel in "${EXTRA_FILES[@]}"; do
  [[ -f "$EXTRAS/$rel" ]] || error "Missing: overrides/end4-pC/$rel"
  [[ ! -e "$STAGE_QS/$rel" ]] || error "Extra file already exists in pinned base: $rel"
  mkdir -p "$(dirname -- "$STAGE_QS/$rel")"
  cp -p -- "$EXTRAS/$rel" "$STAGE_QS/$rel"
done

git -C "$STAGE_QS" -c core.pager=cat diff --check || error 'Patch adds whitespace errors.'
note 'Isolated patch compatibility: OK'
note 'Additional QML files: OK'
note 'Public files privacy check: OK (pattern-based, not an exhaustive audit)'
note 'Potential target locations: ~/.config/{hypr,rofi,kitty,fish,fastfetch,systemd/user}, ~/.local/bin'
note 'Services will NOT be enabled, packages will NOT be installed, active apps will NOT be restarted.'

if [[ "$MODE" == '--check' ]]; then
  note 'READ-ONLY CHECK PASSED. No files were changed.'
  exit 0
fi

# Unlike --check, --apply must refuse to modify an existing customized checkout.
[[ "$CURRENT" == "$BASE" ]] || error 'Cannot apply to a different upstream checkout. Use the pinned version on a test system.'
if [[ -n "$(git -C "$QS" status --porcelain --untracked-files=normal)" ]]; then
  error 'Active end4-pC has local changes. Installer refuses to overwrite them; test on a clean setup.'
fi
git -C "$QS" apply --check "$PATCH" || error 'Patch cannot be applied to the active end4-pC checkout.'
for rel in "${EXTRA_FILES[@]}"; do
  [[ ! -e "$QS/$rel" ]] || error "Refusing to overwrite existing QML file: $QS/$rel"
done

cat <<'CONFIRM' 

WARNING: --apply updates configuration files under your home directory.
You should run this on a CLEAN TEST SYSTEM first, not your customized daily
setup. Your original files are backed up, but changes won't be auto-reverted.
Hyprland must NOT be reloaded until you've checked the new Lua configuration.
Type APLICAR to proceed, or anything else to cancel:
CONFIRM
read -r confirmation
[[ "$confirmation" == 'APLICAR' ]] || { note 'Cancelled. Nothing changed.'; exit 0; }

stamp="$(date +%Y%m%d-%H%M%S)-$$"
backup="$BACKUP_ROOT/$stamp"
mkdir -p "$backup"

# Backup the entire upstream shell. May require disk space (~hundreds of MB).
note 'Backing up existing end4-pC checkout...'
mkdir -p "$backup/quickshell"
cp -a -- "$QS" "$backup/quickshell/end4-pC"
install_started=1

backup_and_copy() {
  local from="$1" to="$2" rel="$3" old="$backup/originals/$rel"
  [[ ! -L "$from" && -f "$from" ]] || error "Unexpected non-file or link: $from"
  [[ ! -L "$to" ]] || error "Refusing to replace symlink: $to"
  if [[ -e "$to" ]]; then
    [[ -f "$to" ]] || error "Refusing to overwrite non-file destination: $to"
    mkdir -p "$(dirname -- "$old")"
    cp -a -- "$to" "$old"
  else
    printf '%s\\0' "$to" >> "$backup/created-files.bin"
  fi
  mkdir -p "$(dirname -- "$to")"
  cp -p -- "$from" "$to"
}

# Apply theme-specific changes while preserving the Git checkout.
git -C "$QS" apply "$PATCH"
for rel in "${EXTRA_FILES[@]}"; do
  backup_and_copy "$EXTRAS/$rel" "$QS/$rel" "quickshell/end4-pC/$rel"
done

# Copy only the public directories, preserving each destination file if present.
PUBLIC_CONFIGS=(rofi kitty fish fastfetch 'hypr/hyprland' 'systemd/user')
for folder in "${PUBLIC_CONFIGS[@]}"; do
  source_dir="$ROOT/dots/.config/$folder"
  [[ -d "$source_dir" ]] || continue
  while IFS= read -r -d '' source_file; do
    rel="${source_file#"$ROOT/dots/.config/"}"
    backup_and_copy "$source_file" "$HOME/.config/$rel" ".config/$rel"
  done < <(find "$source_dir" -type f -print0)
done

source_bin="$ROOT/dots/.local/bin"
if [[ -d "$source_bin" ]]; then
  while IFS= read -r -d '' source_file; do
    rel="${source_file#"$source_bin/"}"
    backup_and_copy "$source_file" "$HOME/.local/bin/$rel" ".local/bin/$rel"
  done < <(find "$source_bin" -type f -print0)
fi

# Install themes through the same backup/rollback mechanism as the other dotfiles.
for theme in changli hiyuki emilia furina hotline-miami; do
  backup_and_copy "$ROOT/end4-pC/$theme.json" "$II/schemes/$theme.json" ".config/illogical-impulse/schemes/$theme.json"
  backup_and_copy "$ROOT/fastfetch/$theme.json" "$HOME/.config/fastfetch/themes/$theme.json" ".config/fastfetch/themes/$theme.json"
done
install_started=0

note "Installed. Backup directory: $backup"
note 'Theme systemd units are present, but NOT enabled.'
note 'Review ~/.config/hypr/hyprland and wallpaper paths before reloading Hyprland.'
note 'For theme changes, open end4-pC Settings > Color scheme.'
note 'Controller Mode and the Steam Window Guard were not installed or modified.'
