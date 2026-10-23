#!/usr/bin/env python3
"""Hermetic installer smoke tests. Uses temporary directories, never the real HOME."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


SCRIPT = Path(__file__).resolve().parents[1] / "install-desktop.sh"
EXTRA = [
    "modules/ii/settings/DashboardCheatsheetPage.qml",
    "modules/ii/wallpaperSelector/AnimatedWallpaperGrid.qml",
    "scripts/animated-picker.py",
    "services/WallpaperLayouts.qml",
]


def run(command, env=None, answer=None):
    return subprocess.run(
        command, env=env, input=answer, capture_output=True, text=True, timeout=30
    )


def main():
    with tempfile.TemporaryDirectory(prefix="hyprland-themes-tests-") as directory:
        root = Path(directory)
        home = root / "home"
        repo = root / "fixture"
        qs = home / ".config/quickshell/end4-pC"
        ii = home / ".config/illogical-impulse"
        qs.mkdir(parents=True)
        ii.mkdir(parents=True)
        (repo / "dots/.config/hypr/hyprland").mkdir(parents=True)
        (repo / "overrides/end4-pC").mkdir(parents=True)
        shutil.copy2(SCRIPT, repo / "install-desktop.sh")
        (repo / "install.sh").write_text("#!/bin/bash\nexit 0\n")
        (repo / "dots/.config/hypr/hyprland/keybinds.lua").write_text("-- fixture\n")
        (repo / "dots/.config/rofi").mkdir(parents=True)
        (repo / "dots/.config/rofi/config.rasi").write_text("configuration {}\n")

        for theme in ("changli", "hiyuki", "emilia", "furina", "hotline-miami"):
            for folder in ("end4-pC", "fastfetch"):
                (repo / folder).mkdir(exist_ok=True)
                (repo / folder / (theme + ".json")).write_text("{}\n")
        for path in EXTRA:
            extra = repo / "overrides/end4-pC" / path
            extra.parent.mkdir(parents=True, exist_ok=True)
            extra.write_text("// fixture\n")

        qml = qs / "modules/common/Config.qml"
        qml.parent.mkdir(parents=True)
        qml.write_text("original\n")
        def git(*args):
            proc = run(["git", "-C", str(qs), *args])
            assert proc.returncode == 0, proc.stderr
            return proc.stdout.strip()
        git("init", "-b", "main")
        git("add", ".")
        proc = run([
            "git", "-C", str(qs), "-c", "user.name=Test",
            "-c", "user.email=test@localhost", "commit", "-m", "fixture"
        ])
        assert proc.returncode == 0, proc.stderr
        base = git("rev-parse", "HEAD")
        (repo / "overrides/end4-pC-base-commit.txt").write_text(base + "\n")
        qml.write_text("modified\n")
        (repo / "overrides/end4-pC-custom.patch").write_text(git("diff", "--binary") + "\n")
        git("restore", ".")

        env = {**os.environ, "HOME": str(home), "GIT_PAGER": "cat"}
        script = ["bash", str(repo / "install-desktop.sh")]

        check = run(script + ["--check"], env)
        assert check.returncode == 0 and "READ-ONLY CHECK PASSED" in check.stdout, check.stderr
        assert qml.read_text() == "original\n", "check modified active Quickshell"

        canceled = run(script + ["--apply"], env, "N\n")
        assert canceled.returncode == 0 and "Cancelled." in canceled.stdout
        assert qml.read_text() == "original\n"

        # Inject a one-time copy failure after earlier files have been installed.
        binary = root / "mock-bin"
        binary.mkdir()
        wrapper = binary / "cp"
        marker = root / "failed-once"
        wrapper.write_text(
            '#!/bin/bash\n'
            f'if [[ "$*" == *"furina.json"* && ! -f "{marker}" ]]; then\n'
            f'  touch "{marker}"; exit 44\n'
            'fi\nexec /usr/bin/cp "$@"\n'
        )
        wrapper.chmod(0o755)
        failed = run(script + ["--apply"], {**env, "PATH": str(binary) + ":" + env["PATH"]}, "APLICAR\n")
        assert failed.returncode != 0 and "Recovery attempted" in failed.stdout, (failed.stdout, failed.stderr)
        assert qml.read_text() == "original\n", "rollback did not restore Quickshell"
        assert not (home / ".config/rofi/config.rasi").exists(), "rollback left a new file"
        assert not (ii / "schemes/changli.json").exists(), "rollback left a new theme"

        applied = run(script + ["--apply"], env, "APLICAR\n")
        assert applied.returncode == 0, applied.stderr
        assert qml.read_text() == "modified\n"
        assert (home / ".config/rofi/config.rasi").is_file()
        assert (ii / "schemes/furina.json").is_file()
        assert run(script + ["--check"], env).returncode == 0

        # Preparation clones a pinned upstream checkout into an otherwise clean test HOME.
        second = root / "new-home"
        (second / ".config/illogical-impulse").mkdir(parents=True)
        fresh_env = {**env, "HOME": str(second), "END4_PC_SOURCE": str(qs)}
        prepared = run(script + ["--prepare-base"], fresh_env)
        assert prepared.returncode == 0, prepared.stderr
        new_qs = second / ".config/quickshell/end4-pC"
        assert run(["git", "-C", str(new_qs), "rev-parse", "HEAD"]).stdout.strip() == base
        refused = run(script + ["--prepare-base"], fresh_env)
        assert refused.returncode != 0, "must refuse overwriting existing checkout"
        assert run(script + ["--check"], fresh_env).returncode == 0

        print("PASS: read-only check, cancellation, rollback, apply, pinned clone and refusal to overwrite")


if __name__ == "__main__":
    main()
