# Hyprland Themes

Character-inspired themes for **Hyprland + Quickshell (illogical-impulse / end4-pC)** and **Fastfetch** on Arch Linux.

> **This is a customization pack, not a replacement for the upstream desktop.** The desktop, widgets, launcher and Hyprland/Quickshell base come from the projects credited below. Install those first; then apply these themes. The author's entire personal dotfiles/preset have **not yet been exported** to this repository.

## Themes

| Theme | Inspired by |
| --- | --- |
| Changli | Wuthering Waves |
| Hiyuki | Wuthering Waves |
| Emilia | Re:Zero |
| Furina | Genshin Impact |
| Hotline Miami | Hotline Miami |

## Install the desktop base first

These themes were designed on top of two existing projects:

1. **[end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)** — original illogical-impulse environment (Hyprland, Quickshell and supporting tools). Follow its **[official installation instructions](https://ii.clsty.link/tr/ii-qs/01setup/)**. Its interactive setup installs system packages and desktop configuration, so review the instructions and backups before running it.
2. **[pctrade/end4-pC](https://github.com/pctrade/end4-pC)** — the customized Quickshell interface that our themes target. It **requires illogical-impulse to be installed first**.

Once the original illogical-impulse base is running, install the end4-pC shell (only if not already present):

```bash
mkdir -p ~/.config/quickshell
git clone https://github.com/pctrade/end4-pC.git ~/.config/quickshell/end4-pC
```

Follow the upstream end4-pC README to launch it or make it the default shell. For example, in the original Hyprland Lua setup, the upstream documentation uses `hl.env("qsConfig", "end4-pC")` in `~/.config/hypr/hyprland/variables.lua` to select the default shell, followed by `hyprctl reload`. **Do not create a second Quickshell instance on top of an existing one by accident.**

## Install the character themes

After the desktop base is installed:

```bash
git clone https://github.com/pedrogonzalez-png/Hyprland-Themes.git
cd Hyprland-Themes
bash install.sh --all
```

Or install just one character:

```bash
bash install.sh changli
```

Options: `--list`, `--all`, or a theme name (`changli`, `hiyuki`, `emilia`, `furina`, `hotline-miami`).

The script checks for the desktop base, copies only the named theme JSONs, and backs up any different existing theme files to `~/.local/share/hyprland-themes/backups/`. It does **not** modify wallpapers, keybinds, services, system packages or the running shell. No `sudo` required.

Then open **end4-pC Settings → Color scheme** and select the character's scheme. The command-line installer does not automatically change the active scheme.

To try a Fastfetch theme:

```bash
fastfetch --config "$HOME/.config/fastfetch/themes/changli.json"
```

The `fastfetch/` files are standalone configurations; the installer keeps them under `~/.config/fastfetch/themes/` without overwriting your normal Fastfetch config.

## Repository contents

```text
end4-pC/       Five named end4-pC color schemes
fastfetch/     Five matching Fastfetch configurations
install.sh     Safe theme installer with backups
README.md      Dependencies, setup and usage
```

## What's not included yet

A portable copy of the author's **complete custom desktop setup** (widget layouts, Hyprland Lua customizations, theme/wallpaper auto-switcher and other local tweaks) still needs to be collected, cleaned of private paths and secrets, and tested before publication. This repository does **not** contain the private DualSense Controller Mode/game launcher.

Wallpapers and copyrighted character images are not bundled. Supply your own wallpapers.

## Credits

- [end-4](https://github.com/end-4/dots-hyprland) — original illogical-impulse project.
- [pctrade](https://github.com/pctrade/end4-pC) — end4-pC Quickshell fork.
- Original games and characters belong to their respective creators; this repository is an unofficial fan customization.

These themes are an add-on, not an official release of either upstream project.
