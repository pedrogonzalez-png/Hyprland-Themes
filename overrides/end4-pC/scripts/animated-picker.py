#!/usr/bin/env python3
"""Animated wallpapers for end4-pC: local gallery, thumbnails and mpvpaper.

Commands: scan | apply <path> | stop | add <existing-video>
This does not modify end4-pC JSON, wallpaperPath, Matugen or Hyprland config.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time

HOME = Path.home()
FOLDER = HOME / "Pictures" / "Wallpapers" / "Animated"
CACHE = HOME / ".cache" / "end4pc-animated-wallpapers"
THUMBS = CACHE / "thumbnails"
PREVIEWS = CACHE / "previews"
STATE = CACHE / "active.json"
EXTENSIONS = {".mp4", ".mkv", ".webm", ".mov", ".gif", ".m4v"}


def report(**data):
    print(json.dumps(data, ensure_ascii=False))


def ensure_dirs():
    FOLDER.mkdir(parents=True, exist_ok=True)
    THUMBS.mkdir(parents=True, exist_ok=True)
    PREVIEWS.mkdir(parents=True, exist_ok=True)


def videos():
    ensure_dirs()
    # Do not recurse into arbitrary large folders. Follow symlinks intentionally
    # added in Animated/, so existing Downloads videos need not be duplicated.
    return sorted((p for p in FOLDER.iterdir() if p.is_file() and p.suffix.lower() in EXTENSIONS),
                  key=lambda p: p.name.casefold())[:250]


def key_for(video):
    st = video.stat()
    return hashlib.sha256(f"{video.resolve()}:{st.st_mtime_ns}:{st.st_size}".encode()).hexdigest()[:28]


def make_thumbnail(video):
    out = THUMBS / (key_for(video) + ".jpg")
    if out.is_file() and out.stat().st_size > 0:
        return str(out)
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        return ""
    temp = out.with_suffix(".part.jpg")
    for seek in ("2", "0"):
        try:
            subprocess.run([ffmpeg, "-nostdin", "-loglevel", "error", "-y", "-ss", seek,
                            "-i", str(video), "-frames:v", "1", "-vf", "scale=360:-2",
                            "-q:v", "4", str(temp)], timeout=30,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            if temp.is_file() and temp.stat().st_size > 0:
                temp.replace(out)
                return str(out)
        except (OSError, subprocess.TimeoutExpired):
            pass
        finally:
            temp.unlink(missing_ok=True)
    return ""


def do_preview(path):
    """Generate one 2.5s loop only on user hover; cached by video hash.

    Security: accept only files currently listed under the Animated gallery.
    """
    ensure_dirs()
    known = {str(v.resolve()): v for v in videos()}
    source = str(Path(path).expanduser().resolve())
    if source not in known:
        raise RuntimeError("Vídeo fora da galeria Animated")
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise RuntimeError("Instale ffmpeg para visualizar a animação")
    video = known[source]
    output = PREVIEWS / (key_for(video) + ".gif")
    if output.is_file() and output.stat().st_size > 0:
        report(ok=True, path=str(output), cached=True)
        return
    temp = output.with_suffix(".tmp.gif")
    try:
        # Duration/framerate/resolution are intentionally small for interactive hover.
        proc = subprocess.run(
            [ffmpeg, "-nostdin", "-loglevel", "error", "-y",
             "-ss", "1", "-i", str(video), "-an", "-t", "2.5",
             "-vf", "fps=8,scale=320:-2:flags=bicubic", "-loop", "0", str(temp)],
            timeout=60, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            check=False)
        # Fallback for very short videos
        if proc.returncode != 0 or not temp.is_file() or temp.stat().st_size == 0:
            temp.unlink(missing_ok=True)
            proc = subprocess.run(
                [ffmpeg, "-nostdin", "-loglevel", "error", "-y", "-i", str(video),
                 "-an", "-t", "2", "-vf", "fps=8,scale=320:-2:flags=bicubic",
                 "-loop", "0", str(temp)],
                timeout=60, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                check=False)
        if proc.returncode != 0 or not temp.is_file() or temp.stat().st_size == 0:
            raise RuntimeError("Não foi possível criar a prévia GIF deste vídeo")
        temp.replace(output)
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError("FFmpeg excedeu o tempo de geração da prévia") from exc
    finally:
        temp.unlink(missing_ok=True)
    report(ok=True, path=str(output), cached=False)


def read_state():
    try:
        return json.loads(STATE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def active_monitor():
    try:
        completed = subprocess.run(["hyprctl", "monitors", "-j"], timeout=4,
                                   capture_output=True, text=True, check=True)
        monitors = json.loads(completed.stdout)
        if monitors:
            chosen = next((m for m in monitors if m.get("focused")), monitors[0])
            name = chosen.get("name")
            if name:
                return name
    except (OSError, subprocess.SubprocessError, ValueError, IndexError, TypeError):
        pass
    raise RuntimeError("Não consegui detectar um monitor com 'hyprctl monitors -j'.")


def stop_on_monitor(monitor):
    """Stop only this user's mpvpaper on selected output, not other monitors."""
    proc_root = Path("/proc")
    to_stop = []
    for proc in proc_root.iterdir():
        if not proc.name.isdigit():
            continue
        try:
            if proc.stat().st_uid != os.getuid():
                continue
            cmd = (proc / "cmdline").read_bytes().split(b"\x00")
            if not cmd or Path(os.fsdecode(cmd[0])).name != "mpvpaper":
                continue
            if monitor.encode() in cmd:
                to_stop.append(int(proc.name))
        except (OSError, ValueError):
            continue
    for pid in to_stop:
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    if to_stop:
        time.sleep(0.35)
    return to_stop


def do_scan():
    paths = videos()
    selected = read_state().get("path", "")
    items = []
    for video in paths:
        items.append({"path": str(video), "name": video.name,
                      "thumbnail": make_thumbnail(video)})
    report(ok=True, folder=str(FOLDER), active=selected,
           ffmpeg=bool(shutil.which("ffmpeg")), items=items)


def do_apply(path):
    ensure_dirs()
    allowed = {str(p.resolve()): p for p in videos()}
    real = str(Path(path).expanduser().resolve())
    if real not in allowed:
        raise RuntimeError("Vídeo fora da pasta Animated. Adicione pelo comando add.")
    binary = shutil.which("mpvpaper")
    if not binary:
        raise RuntimeError("mpvpaper não instalado. Instale-o antes de aplicar vídeos.")
    monitor = active_monitor()
    # O mesmo MP4 ja esta em reproducao neste monitor? Nao reinicie o mpvpaper.
    for proc_dir in Path("/proc").iterdir():
        if not proc_dir.name.isdigit():
            continue
        try:
            if proc_dir.stat().st_uid != os.getuid():
                continue
            cmd = [item for item in (proc_dir / "cmdline").read_bytes().split(b"\x00") if item]
            if not cmd or Path(os.fsdecode(cmd[0])).name != "mpvpaper":
                continue
            args = [os.fsdecode(item) for item in cmd]
            if monitor not in args or not args[-1]:
                continue
            if Path(args[-1]).expanduser().resolve() == Path(real):
                STATE.write_text(json.dumps({"path": str(allowed[real]), "monitor": monitor,
                                             "pid": int(proc_dir.name)}, ensure_ascii=False), encoding="utf-8")
                report(ok=True, path=str(allowed[real]), monitor=monitor, already_running=True)
                return
        except (OSError, ValueError):
            continue
    stop_on_monitor(monitor)
    logfile = CACHE / "mpvpaper.log"
    with logfile.open("ab") as log:
        process = subprocess.Popen([binary, "-f", "-o", "no-audio loop", monitor, real],
                                   stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                                   start_new_session=True)
    time.sleep(0.35)
    if process.poll() is not None:
        raise RuntimeError(f"mpvpaper encerrou ao iniciar. Confira {logfile}")
    STATE.write_text(json.dumps({"path": str(allowed[real]), "monitor": monitor,
                                  "pid": process.pid}, ensure_ascii=False), encoding="utf-8")
    report(ok=True, path=str(allowed[real]), monitor=monitor)


def do_stop():
    try:
        monitor = active_monitor()
        stop_on_monitor(monitor)
    except RuntimeError:
        pass
    STATE.unlink(missing_ok=True)
    report(ok=True)


def do_add(path):
    ensure_dirs()
    video = Path(path).expanduser().resolve(strict=True)
    if not video.is_file() or video.suffix.lower() not in EXTENSIONS:
        raise RuntimeError("Escolha um arquivo de vídeo suportado.")
    dest = FOLDER / video.name
    if dest.exists() or dest.is_symlink():
        if dest.resolve() == video:
            report(ok=True, path=str(dest), existing=True)
            return
        raise RuntimeError(f"Já existe outro arquivo com esse nome em {dest}")
    dest.symlink_to(video)
    report(ok=True, path=str(dest))


def main():
    if len(sys.argv) < 2:
        raise RuntimeError("Uso: animated-picker.py scan|apply <path>|stop|add <path>")
    cmd = sys.argv[1]
    if cmd == "scan":
        do_scan()
    elif cmd == "apply" and len(sys.argv) == 3:
        do_apply(sys.argv[2])
    elif cmd == "stop":
        do_stop()
    elif cmd == "preview" and len(sys.argv) == 3:
        do_preview(sys.argv[2])
    elif cmd == "add" and len(sys.argv) == 3:
        do_add(sys.argv[2])
    else:
        raise RuntimeError("Comando desconhecido ou faltando argumento")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError) as exc:
        report(ok=False, error=str(exc))
        sys.exit(1)
