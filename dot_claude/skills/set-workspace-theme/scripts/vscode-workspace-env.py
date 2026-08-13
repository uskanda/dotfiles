#!/usr/bin/env python3
"""Collect the facts /set-workspace-theme needs, as one JSON blob on stdout.

Read-only. Never writes VS Code state -- the skill edits settings files itself
so that comments and formatting survive.

Reports:
  target       which settings file owns the current workspace
  openWindows  other VS Code windows that are open, and the theme each uses
  themes       every color theme installed on this machine, with background metrics
  suggestions  themes ranked by hue distance from the ones already in use

Usage: python3 vscode-workspace-env.py [workspace-dir]   (default: cwd)
"""

import colorsys
import glob
import json
import os
import re
import sys
from urllib.parse import unquote, urlparse

# --------------------------------------------------------------------------
# JSONC
# --------------------------------------------------------------------------


def strip_jsonc(text):
    """Drop comments and trailing commas without touching string literals."""
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == '"':
            j = i + 1
            while j < n:
                if text[j] == "\\":
                    j += 2
                    continue
                if text[j] == '"':
                    break
                j += 1
            out.append(text[i : j + 1])
            i = j + 1
        elif c == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                i += 1
        elif c == "/" and i + 1 < n and text[i + 1] == "*":
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
        else:
            out.append(c)
            i += 1
    return re.sub(r",(\s*[}\]])", r"\1", "".join(out))


def read_jsonc(path):
    try:
        with open(path, encoding="utf-8-sig") as fh:
            return json.loads(strip_jsonc(fh.read()))
    except Exception:
        return None


# --------------------------------------------------------------------------
# Platform paths
# --------------------------------------------------------------------------


def user_data_dir():
    home = os.path.expanduser("~")
    if sys.platform == "win32":
        base = os.environ.get("APPDATA") or os.path.join(home, "AppData", "Roaming")
        return os.path.join(base, "Code", "User")
    if sys.platform == "darwin":
        return os.path.join(home, "Library", "Application Support", "Code", "User")
    cfg = os.environ.get("XDG_CONFIG_HOME") or os.path.join(home, ".config")
    return os.path.join(cfg, "Code", "User")


def builtin_extension_dirs():
    """Where the app ships its bundled themes. Layout moved in VS Code 1.132:
    the app payload now sits under a commit-hash directory."""
    home = os.path.expanduser("~")
    roots = []
    if sys.platform == "win32":
        local = os.environ.get("LOCALAPPDATA") or os.path.join(home, "AppData", "Local")
        roots += [
            os.path.join(local, "Programs", "Microsoft VS Code"),
            r"C:\Program Files\Microsoft VS Code",
        ]
    elif sys.platform == "darwin":
        roots += ["/Applications/Visual Studio Code.app/Contents/Resources/app"]
    else:
        roots += ["/usr/share/code", "/usr/lib/code", "/opt/visual-studio-code"]

    found = []
    for root in roots:
        if not os.path.isdir(root):
            continue
        for pat in ("resources/app/extensions", "*/resources/app/extensions", "extensions"):
            found += [d for d in glob.glob(os.path.join(root, pat)) if os.path.isdir(d)]
    return found


def user_extension_dir():
    return os.path.join(os.path.expanduser("~"), ".vscode", "extensions")


# --------------------------------------------------------------------------
# Color metrics
# --------------------------------------------------------------------------


def metrics(hex_color):
    h = hex_color.lstrip("#")
    if len(h) < 6:
        return None
    try:
        r, g, b = (int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))
    except ValueError:
        return None
    hue, light, sat = colorsys.rgb_to_hls(r, g, b)
    return {
        "bg": "#" + h[:6].upper(),
        "hue": round(hue * 360),
        "sat": round(sat * 100),
        "light": round(light * 100),
        # chroma separates "deep navy" from "neon magenta"; HSL saturation cannot
        # (#390000 and #FF0000 are both S=100)
        "chroma": round((max(r, g, b) - min(r, g, b)) * 100),
        "luma": round((0.2126 * r + 0.7152 * g + 0.0722 * b) * 100),
    }


# Thresholds for "not fit to sit behind code all day". Deliberately loose --
# every stock theme passes; these only catch loud third-party themes.
CHROMA_MAX = 45
DARK_LUMA_MAX = 30
LIGHT_LUMA_MIN = 75
NEUTRAL_CHROMA = 6  # below this the hue is noise, not a color


def judge(m, ui_theme):
    reasons = []
    if m["chroma"] > CHROMA_MAX:
        reasons.append(f"彩度が高すぎる (chroma={m['chroma']})")
    dark = (ui_theme or "").startswith(("vs-dark", "hc-black"))
    if dark and m["luma"] > DARK_LUMA_MAX:
        reasons.append(f"暗色テーマとしては明るすぎる (luma={m['luma']})")
    if not dark and m["luma"] < LIGHT_LUMA_MIN:
        reasons.append(f"明色テーマとしては暗すぎる (luma={m['luma']})")
    return reasons


# --------------------------------------------------------------------------
# Theme catalog
# --------------------------------------------------------------------------


def nls_lookup(ext_dir):
    return read_jsonc(os.path.join(ext_dir, "package.nls.json")) or {}


def resolve_bg(theme_path, depth=0):
    """editor.background, following `include` chains."""
    if depth > 5:
        return None
    d = read_jsonc(theme_path)
    if not d:
        return None
    color = (d.get("colors") or {}).get("editor.background")
    if color:
        return color
    inc = d.get("include")
    if inc:
        return resolve_bg(os.path.normpath(os.path.join(os.path.dirname(theme_path), inc)), depth + 1)
    return None


def collect_themes():
    themes, seen = [], set()
    sources = [(d, "builtin") for d in builtin_extension_dirs()]
    sources.append((user_extension_dir(), "extension"))

    for base, origin in sources:
        for pkg_path in glob.glob(os.path.join(base, "*", "package.json")):
            pkg = read_jsonc(pkg_path)
            if not pkg:
                continue
            contributes = (pkg.get("contributes") or {}).get("themes") or []
            if not contributes:
                continue
            ext_dir = os.path.dirname(pkg_path)
            nls = nls_lookup(ext_dir)

            for t in contributes:
                label = t.get("label") or ""
                if label.startswith("%") and label.endswith("%"):
                    label = nls.get(label[1:-1], label)
                # `workbench.colorTheme` matches on id when the theme declares
                # one; the label is localized by language packs and unsafe.
                settings_id = t.get("id") or label
                if not settings_id or settings_id in seen:
                    continue
                rel = (t.get("path") or "").lstrip("./")
                color = resolve_bg(os.path.normpath(os.path.join(ext_dir, rel)))
                m = color and metrics(color)
                if not m:
                    continue
                seen.add(settings_id)
                entry = {
                    "settingsId": settings_id,
                    "label": label or settings_id,
                    "uiTheme": t.get("uiTheme"),
                    "source": origin,
                    "extension": os.path.basename(ext_dir),
                    **m,
                }
                entry["neutral"] = m["chroma"] < NEUTRAL_CHROMA
                entry["unsuitable"] = judge(m, t.get("uiTheme"))
                themes.append(entry)
    return themes


# --------------------------------------------------------------------------
# Open windows
# --------------------------------------------------------------------------


def uri_to_local(uri):
    """file:/// and vscode-remote:// URIs -> a path this machine can read.
    Returns (path_or_None, remote_authority_or_None)."""
    if not uri:
        return None, None
    p = urlparse(uri)
    path = unquote(p.path)
    if p.scheme == "file":
        if sys.platform == "win32" and re.match(r"^/[A-Za-z]:", path):
            path = path[1:]
        return os.path.normpath(path), None

    if p.scheme == "vscode-remote":
        authority = unquote(p.netloc)
        if authority.startswith("wsl+") and sys.platform == "win32":
            distro = authority[4:]
            for unc in (r"\\wsl.localhost", r"\\wsl$"):
                cand = unc + "\\" + distro + path.replace("/", "\\")
                if os.path.isdir(cand):
                    return cand, authority
            return None, authority
        if authority.startswith("wsl+") and sys.platform.startswith("linux"):
            # already inside WSL: the path is local
            return os.path.normpath(path), authority
        return None, authority  # ssh-remote / dev container: not reachable from here
    return None, p.netloc or None


def workspace_file_folders(ws_file):
    """Folder paths declared by a .code-workspace file."""
    d = read_jsonc(ws_file)
    if not d:
        return []
    base = os.path.dirname(ws_file)
    out = []
    for f in d.get("folders") or []:
        p = f.get("path")
        if p:
            out.append(os.path.normpath(p if os.path.isabs(p) else os.path.join(base, p)))
    return out


def open_windows():
    store = read_jsonc(os.path.join(user_data_dir(), "globalStorage", "storage.json")) or {}
    state = store.get("windowsState") or {}
    entries = list(state.get("openedWindows") or [])
    last = state.get("lastActiveWindow")
    if last:
        entries.append(last)

    windows, seen = [], set()
    for e in entries:
        wsid = e.get("workspaceIdentifier") or {}
        config_uri = wsid.get("configURIPath")
        folder_uri = e.get("folder")
        key = config_uri or folder_uri
        if not key or key in seen:
            continue
        seen.add(key)

        if config_uri:
            path, remote = uri_to_local(config_uri)
            windows.append(
                {
                    "kind": "workspaceFile",
                    "uri": config_uri,
                    "workspaceFile": path,
                    "folders": workspace_file_folders(path) if path else [],
                    "remote": remote or e.get("remoteAuthority"),
                }
            )
        else:
            path, remote = uri_to_local(folder_uri)
            windows.append(
                {
                    "kind": "folder",
                    "uri": folder_uri,
                    "folder": path,
                    "folders": [path] if path else [],
                    "remote": remote or e.get("remoteAuthority"),
                }
            )
    return windows


def window_settings_file(w):
    if w["kind"] == "workspaceFile":
        return w.get("workspaceFile")
    return os.path.join(w["folder"], ".vscode", "settings.json") if w.get("folder") else None


def read_window_settings(w):
    """(settings dict, path) for a window, or (None, path) if unreadable."""
    path = window_settings_file(w)
    if not path or not os.path.isfile(path):
        return None, path
    d = read_jsonc(path)
    if d is None:
        return None, path
    return (d.get("settings") or {}) if w["kind"] == "workspaceFile" else d, path


# --------------------------------------------------------------------------
# Assembly
# --------------------------------------------------------------------------


def same_path(a, b):
    if not a or not b:
        return False
    return os.path.normcase(os.path.normpath(a)) == os.path.normcase(os.path.normpath(b))


def hue_distance(a, b):
    d = abs(a - b) % 360
    return min(d, 360 - d)


def main():
    # Windows Python encodes stdout with the ANSI codepage (CP932 here), which
    # mangles the Japanese strings below the moment output is piped.
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except AttributeError:
        pass

    target_dir = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.getcwd())
    udir = user_data_dir()
    user_settings_path = os.path.join(udir, "settings.json")
    user_settings = read_jsonc(user_settings_path) or {}
    user_theme = user_settings.get("workbench.colorTheme")

    themes = collect_themes()
    by_id = {t["settingsId"]: t for t in themes}

    windows = open_windows()
    for w in windows:
        s, path = read_window_settings(w)
        w["settingsFile"] = path
        w["settingsFileExists"] = bool(path and os.path.isfile(path))
        w["colorTheme"] = (s or {}).get("workbench.colorTheme")
        w["windowTitle"] = (s or {}).get("window.title")
        w["inherited"] = w["colorTheme"] is None
        effective = w["colorTheme"] or user_theme
        w["effectiveTheme"] = effective
        info = by_id.get(effective) if effective else None
        w["effectiveThemeInfo"] = (
            {k: info[k] for k in ("bg", "hue", "chroma", "neutral", "uiTheme")} if info else None
        )
        w["isTarget"] = any(same_path(f, target_dir) for f in w.get("folders") or [])

    # Which window owns target_dir? A multi-root workspace wins over a bare
    # folder: window-scoped settings live in the .code-workspace file there,
    # and a folder's .vscode/settings.json would be ignored.
    owners = [w for w in windows if w["isTarget"]]
    owners.sort(key=lambda w: 0 if w["kind"] == "workspaceFile" else 1)
    target = owners[0] if owners else None

    if target:
        resolved = {
            "kind": target["kind"],
            "settingsFile": target["settingsFile"],
            "settingsFileExists": target["settingsFileExists"],
            "settingsKeyPath": "settings" if target["kind"] == "workspaceFile" else "",
            "workspaceFile": target.get("workspaceFile"),
            "folders": target.get("folders"),
            "remote": target.get("remote"),
            "currentColorTheme": target["colorTheme"],
            "currentWindowTitle": target["windowTitle"],
        }
    else:
        # Not found among open windows (storage.json lags a fresh window).
        # Fall back to treating target_dir as a single-folder workspace.
        fallback = os.path.join(target_dir, ".vscode", "settings.json")
        existing = read_jsonc(fallback) or {}
        resolved = {
            "kind": "folder",
            "settingsFile": fallback,
            "settingsFileExists": os.path.isfile(fallback),
            "settingsKeyPath": "",
            "workspaceFile": None,
            "folders": [target_dir],
            "remote": None,
            "currentColorTheme": existing.get("workbench.colorTheme"),
            "currentWindowTitle": existing.get("window.title"),
            "note": "開いているウィンドウ一覧に一致するものが無かったため、単一フォルダの workspace とみなした。ユーザーに確認すること。",
        }

    others = [w for w in windows if not w["isTarget"]]
    taken = [
        {"theme": w["effectiveTheme"], **(w["effectiveThemeInfo"] or {})}
        for w in others
        if w.get("effectiveThemeInfo")
    ]
    # A window with no theme of its own falls back to the user setting, and if
    # that is unset too, to VS Code's built-in default. Every candidate for that
    # default (Dark Modern #1F1F1F, Dark 2026 #121314, Light Modern #FFFFFF) is
    # achromatic, so book it as a neutral rather than guessing the exact id.
    if any(w["inherited"] for w in others) and not user_theme:
        taken.append({"theme": "(VS Code 既定テーマ)", "neutral": True, "assumed": True})
    taken_hues = [t["hue"] for t in taken if not t.get("neutral")]
    neutral_taken = any(t.get("neutral") for t in taken)

    def score(t):
        if t["neutral"]:
            # neutrals only clash with other neutrals
            return -1 if neutral_taken else 45
        if not taken_hues:
            return 180
        return min(hue_distance(t["hue"], h) for h in taken_hues)

    candidates = [
        {**t, "hueDistance": score(t)}
        for t in themes
        if not t["unsuitable"] and t["settingsId"] != resolved["currentColorTheme"]
    ]
    # Distinct hue first, then the more visibly tinted one (a theme whose chrome
    # actually reads as colored beats a near-gray), then the darker one.
    candidates.sort(key=lambda t: (-t["hueDistance"], -t["chroma"], t["light"]))

    print(
        json.dumps(
            {
                "targetDir": target_dir,
                "platform": sys.platform,
                "userSettingsPath": user_settings_path,
                "userColorTheme": user_theme,
                "userWindowTitle": user_settings.get("window.title"),
                "target": resolved,
                "openWindowCount": len(windows),
                "otherWindows": [
                    {
                        k: w[k]
                        for k in (
                            "kind",
                            "uri",
                            "folders",
                            "remote",
                            "settingsFile",
                            "colorTheme",
                            "effectiveTheme",
                            "windowTitle",
                            "inherited",
                            "effectiveThemeInfo",
                        )
                    }
                    for w in others
                ],
                "takenColors": taken,
                "suggestions": candidates[:12],
                "themes": sorted(themes, key=lambda t: (t["uiTheme"] or "", t["hue"])),
            },
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
