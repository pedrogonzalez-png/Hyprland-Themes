# Hyprland-Themes

Custom desktop preset and five character-inspired color schemes for **Arch Linux + Hyprland + Quickshell (end-4 illogical-impulse / end4-pC)**. Includes the public Hyprland Lua config, Quickshell widgets and animated-wallpaper modifications, Rofi launcher, Kitty/Fish/Fastfetch settings and wallpaper-to-theme automation.

> **Not a standalone desktop distribution.** First install [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) using its [official instructions](https://ii.clsty.link/). The full installer is an experimental customization layer and does not install Arch Linux, Hyprland or all system dependencies.

## Themes

| Scheme | Inspiration |
| --- | --- |
| Changli | Wuthering Waves |
| Hiyuki | Wuthering Waves |
| Emilia | Re:Zero |
| Furina | Genshin Impact |
| Hotline Miami | Hotline Miami |

## Option A: themes only (safer)

For an existing illogical-impulse and [pctrade/end4-pC](https://github.com/pctrade/end4-pC) installation:

```bash
git clone https://github.com/pedrogonzalez-png/Hyprland-Themes.git
cd Hyprland-Themes
bash install.sh --all
# Or only one: bash install.sh changli
```

The theme installer makes backups when overwriting theme files and leaves Hyprland, wallpaper, keybinds and running services untouched. Select a scheme under **end4-pC Settings → Color scheme**. To view a matching Fastfetch preset:

```bash
fastfetch --config "$HOME/.config/fastfetch/themes/changli.json"
```

## Option B: complete desktop customization (experimental)

**Start with a disposable/test Arch user or VM** that already has end-4 illogical-impulse installed. Your end4-pC working tree must be clean and pinned to the commit in [overrides/end4-pC-base-commit.txt](overrides/end4-pC-base-commit.txt). The verified patch base is `8fbb6716cba628a13103e665e9538021683a7250`, from the official pctrade repository.

```bash
git clone https://github.com/pedrogonzalez-png/Hyprland-Themes.git
cd Hyprland-Themes

# ONLY when ~/.config/quickshell/end4-pC does not exist:
bash install-desktop.sh --prepare-base

# Does not change ~/.config or ~/.local:
bash install-desktop.sh --check

# On a test installation, after reviewing changes:
bash install-desktop.sh --apply
```

`--prepare-base` clones pctrade/end4-pC at the pinned commit. It refuses to replace an existing directory. `--apply` refuses an altered or different-version checkout, requires typing `APLICAR`, takes backups and attempts rollback if an ordinary command fails. Backups: `~/.local/share/Hyprland-Themes/backups/`. It does **not** start/stop applications, install system packages, or enable any systemd service. Read [INSTALL-DESKTOP.md](INSTALL-DESKTOP.md) before applying.

If you already have a newer/customized end4-pC checkout, **do not delete or reset it just to run the installer**. Test with a fresh user/VM instead.

### Enable wallpaper-linked themes (optional)

After `--apply` and selecting a wallpaper in end4-pC:

```bash
~/.local/bin/end4-wallpaper-theme status
~/.local/bin/end4-wallpaper-theme bind changli
systemctl --user enable --now end4-wallpaper-theme.path
```

The watcher uses the `wallpaperPath` saved in illogical-impulse config. To unlink a wallpaper, run `~/.local/bin/end4-wallpaper-theme unbind`. To turn off the watcher: `systemctl --user disable --now end4-wallpaper-theme.path`. Wallpaper images and the optional file `wallpaper-scheme-links.json` are **not** included.

### Fastfetch image (optional)

The public `dots/.config/fastfetch/config.jsonc` uses the **automatic OS logo** so it works without a non-redistributable character image. To use your own Changli artwork, save it under `~/.config/fastfetch/images/Changli.webp` and change the logo block in the copied config to:

```json
"logo": {
  "type": "kitty-icat",
  "source": "~/.config/fastfetch/images/Changli.webp",
  "width": 29
}
```

Kitty supports the image protocol. Other terminals may require another logo type. No character images are bundled.

## Contents

```text
end4-pC/                Five Quickshell color schemes
fastfetch/               Five matching Fastfetch presets
dots/                    Exported public Hyprland, Rofi, Kitty, Fish, Fastfetch and systemd config
overrides/               Pinned Quickshell patch and four new source files
install.sh               Themes-only installer
install-desktop.sh       Experimental full-customization installer
INSTALL-DESKTOP.md       Safety notes, preparation and recovery
```

The included Hyprland configuration references programs such as `qs`, `rofi`, `kitty`, `fish`, `fastfetch`, `btop`, `tty-clock`, `hyprshot`, and other upstream utilities. Their presence is not fully validated by `--check`; install required programs as needed following upstream instructions.

**Not bundled:** private Controller Mode/game launcher and its scripts, Steam integration, user-specific settings, wallpaper files, character artwork or secret credentials. The public cheatsheet retains a nonfunctional reference to an old gaming-time shortcut; it does not install that tracker.

## Credits

- [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) — upstream illogical-impulse desktop.
- [pctrade/end4-pC](https://github.com/pctrade/end4-pC) — Quickshell fork customized here.
- Character/game names and art belong to their respective owners. Unofficial fan project.
