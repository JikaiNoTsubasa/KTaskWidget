# KTaskWidget — Build & Install Guide

This widget is **pure QML/JavaScript**. There is no native compilation step — QML is interpreted at runtime by Plasma. "Building" here means **packaging** the source directory into a `.plasmoid` archive (a zip with a specific layout) that Plasma's GUI accepts via *Install Widget from Local File*.

If you don't need the archive, you can skip straight to [§3 Direct install via kpackagetool5](#3-direct-install-via-kpackagetool5) — it installs the source directory directly.

---

## 1. Prerequisites

Verify your environment:

| Requirement | Check | Where to get it |
| --- | --- | --- |
| **KDE Plasma 5** desktop | `plasmashell --version` should print `5.x` (typically 5.27 on Kubuntu LTS) | Ships with Kubuntu. Not for Plasma 6 — see [Known limitations](IMPLEMENTATION.md#7-known-limitations). |
| **kpackagetool5** | `which kpackagetool5` | `sudo apt install plasma-framework` |
| **plasmoidviewer** (dev only) | `which plasmoidviewer` | `sudo apt install plasma-sdk` |
| **zip** | `which zip` | `sudo apt install zip` |
| **make** | `which make` | `sudo apt install make` |

One-liner for Kubuntu/Debian users:

```sh
sudo apt install plasma-framework plasma-sdk zip make
```

`plasma-sdk` is only needed if you want to use `plasmoidviewer` during development. End users do not need it.

---

## 2. Quick install (recommended for the impatient)

From the repo root:

```sh
make install
```

That's it. The widget is now available in the "Add Widgets" picker. Right-click your panel → **Add Widgets…** → search **Task Widget** → drag onto the panel.

If you've installed before and want to refresh after pulling changes, use `make reinstall` (does `remove` then `install`).

---

## 3. Direct install via kpackagetool5

`make install` is just a wrapper for:

```sh
kpackagetool5 --type Plasma/Applet --install package/org.kde.ktaskwidget
```

This copies the package directory into `~/.local/share/plasma/plasmoids/org.kde.ktaskwidget/`. Plasma scans that directory on its own — no `plasma-restart` needed for the widget to appear in the picker.

Other useful operations:

```sh
# Upgrade an already-installed package (after editing source)
kpackagetool5 --type Plasma/Applet --upgrade package/org.kde.ktaskwidget

# Uninstall
kpackagetool5 --type Plasma/Applet --remove org.kde.ktaskwidget

# List all installed applets (useful for confirming install)
kpackagetool5 --type Plasma/Applet --list | grep ktaskwidget
```

The `Makefile` exposes shortcuts: `make upgrade`, `make remove`, `make reinstall`.

---

## 4. Build the `.plasmoid` archive (for distribution)

If you want to share the widget with someone who won't run `make install` themselves, build a `.plasmoid` archive — Plasma's GUI installer accepts it:

```sh
make package
```

This produces `ktaskwidget.plasmoid` in the repo root. Under the hood:

```sh
cd package/org.kde.ktaskwidget && zip -r ../../ktaskwidget.plasmoid .
```

**Important**: the zip must contain `metadata.desktop` at its **root**, not nested inside an extra directory. The `cd` into the package directory before `zip` is what guarantees this. If you build the archive by hand, double-check with `unzip -l ktaskwidget.plasmoid` — the first entry should be `metadata.desktop`, not `org.kde.ktaskwidget/metadata.desktop`.

### Install the `.plasmoid` archive via the Plasma GUI

1. Right-click your desktop or any panel → **Add Widgets…**
2. At the bottom of the panel that opens, click **Get New Widgets** → **Install Widget from Local File…**
3. In the file picker, choose `ktaskwidget.plasmoid`.
4. Plasma will respond with a small confirmation. The widget now appears in the widget picker as **Task Widget** — drag it onto a panel.

### Install the `.plasmoid` archive from the command line

If you have the archive but not the source:

```sh
kpackagetool5 --type Plasma/Applet --install ktaskwidget.plasmoid
```

`kpackagetool5` accepts either a directory or a `.plasmoid` archive.

---

## 5. Verify the install

After installing, confirm the widget is registered:

```sh
kpackagetool5 --type Plasma/Applet --list | grep ktaskwidget
```

Expected output:

```
org.kde.ktaskwidget
```

You can also check the install directory:

```sh
ls ~/.local/share/plasma/plasmoids/org.kde.ktaskwidget/
```

Expected to contain `metadata.desktop` and `contents/`.

Finally, open the widget picker (right-click panel → **Add Widgets…**) and search for **Task Widget**. If it doesn't appear, see [§8 Troubleshooting](#8-troubleshooting).

---

## 6. Updating an installed widget

The package files on disk and the running widget instance are two separate things. Updating requires touching both.

### Step 1 — refresh the on-disk package

```sh
make install
```

The `install` target is idempotent: if `kpackagetool5` already knows about `org.kde.ktaskwidget`, it runs `--upgrade` (rewriting `~/.local/share/plasma/plasmoids/org.kde.ktaskwidget/`) instead of `--install`. So a single `make install` is the right command whether it's the first time or the tenth.

If you want to be explicit, `make upgrade` does only the upgrade path, and `make reinstall` does `remove` + `install`.

### Step 2 — reload the running instance

`kpackagetool5 --upgrade` rewrites the files on disk but the running plasmashell process keeps the **previously loaded QML Components in memory**. Removing and re-adding the widget from the panel does **not** force a reload — it just instantiates a new Item from the cached Component. To pick up code changes you have to make plasmashell re-read the files. Choose one:

| Method | How | When to use |
| --- | --- | --- |
| **Restart plasmashell (recommended)** | From a **Konsole** (not VS Code's snap terminal): `kquitapp5 plasmashell && kstart5 plasmashell` | **Required for any QML/JS, `metadata.desktop`, `config/main.xml`, or icon change.** Panel blanks for ~1 s. |
| **Log out / log in** | Standard KDE session restart. | Same effect as the above. Slower. Use if `kquitapp5` doesn't behave. |
| **Re-add from panel** | Right-click the widget → **Remove**; right-click panel → **Add Widgets…** → drag **Task Widget** back. | **Only useful when the widget's runtime state is wedged** (e.g. broken ListModel, stuck signal handler). Does **not** pick up code changes. |

**For the dev loop, prefer `make dev` (`plasmoidviewer`) over reinstalling — `plasmoidviewer` re-reads QML on every launch, so there is no cache to clear.**

### Step 3 — verify the update took effect

If you have any doubt the running widget is on the new version, add a unique log line in `main.qml`'s `Component.onCompleted` (e.g. `console.log("[ktaskwidget] loaded vN")`), do steps 1–2, then watch:

```sh
journalctl --user -f _COMM=plasmashell
```

You should see your log line each time a widget instance is created. Remove the log line afterwards.

Your existing tasks are preserved across updates — they live in `~/.config/plasma-org.kde.plasma.desktop-appletsrc`, independent of the plasmoid package files.

---

## 7. Development workflow

Once the prerequisites are installed, the fastest iteration loop is:

```sh
make dev
```

That runs `plasmoidviewer -a package/org.kde.ktaskwidget`, which launches the widget in a standalone window directly from the source directory. QML changes are picked up on each relaunch — no install step required. Persistence works the same way (`plasmoid.configuration` writes to `~/.config/plasma-org.kde.plasma.desktop-appletsrc`), so tasks added in `plasmoidviewer` survive across runs and are visible to panel-installed copies of the widget.

When you change `metadata.desktop` itself, `plasmoidviewer` re-reads it on each launch, but a panel-installed copy needs `make upgrade` (or `make reinstall`) followed by a Plasma reload:

```sh
kquitapp5 plasmashell && kstart5 plasmashell
```

This is only necessary after metadata changes — pure QML/JS edits are picked up on next widget instantiation.

---

## 8. Troubleshooting

### "Task Widget" doesn't appear in the widget picker

1. Confirm the install: `kpackagetool5 --type Plasma/Applet --list | grep ktaskwidget`. If absent, re-run `make install` and watch for errors.
2. Reload plasmashell: `kquitapp5 plasmashell && kstart5 plasmashell`.
3. If `kpackagetool5 --install` succeeded but the widget is still missing, the most likely cause is a syntax error in `metadata.desktop`. Run it through:

   ```sh
   desktop-file-validate package/org.kde.ktaskwidget/metadata.desktop
   ```

   Fix any warnings, then `make reinstall`.

### "Could not load metadata.desktop" or the widget shows a red error icon

The QML failed to load. Run it under `plasmoidviewer` to see the parser/runtime error:

```sh
make dev
```

Errors are printed to stderr. Common causes: a missing import, a typo in a property name, or an unbound `id` reference.

### Tasks aren't persisting across panel reloads

1. Confirm the config key exists after you add a task:

   ```sh
   grep -A 1 tasksJson ~/.config/plasma-org.kde.plasma.desktop-appletsrc
   ```

   If `tasksJson=` is missing, the `contents/config/main.xml` schema isn't being picked up — verify the file exists and contains the `<entry name="tasksJson" …>` element, then `make reinstall`.

2. If the value is being written but doesn't reappear on reload, check stderr from `plasmoidviewer` for JSON parse errors in `loadTasks()`.

### `make install` fails with "package already exists"

You have an older copy installed. Use `make reinstall` (which removes first) or `make upgrade`.

### "Install Widget from Local File…" rejects the `.plasmoid` archive

The zip layout is wrong. Verify with `unzip -l ktaskwidget.plasmoid` — the listing must show `metadata.desktop` at the top level, not nested. If nested, rebuild with `make clean && make package`.

### `kpackagetool5: command not found`

Install Plasma's package framework: `sudo apt install plasma-framework`. On non-Debian distributions, the package may be named `plasma5-frameworks-data` or similar — check your distro's package index.

### Install succeeded but the widget never appears in the picker (VS Code snap trap)

If you ran `make install` from VS Code's **integrated terminal** and VS Code is installed via **snap**, the snap sandbox sets `XDG_DATA_HOME=$HOME/snap/code/<rev>/.local/share`. `kpackagetool5` honors that env var, so the widget gets installed into the snap's confined `$HOME` — a path plasmashell never reads. Symptoms: `make install` prints "Successfully installed", `kpackagetool5 --show org.kde.ktaskwidget` reports a path under `~/snap/code/<rev>/...`, but the widget is missing from "Add Widgets…".

The `Makefile` in this repo forces `XDG_DATA_HOME=$HOME/.local/share` to dodge this — so re-running `make install` from any shell should work. If you somehow bypassed it (e.g. invoked `kpackagetool5` by hand), fix it with:

```sh
XDG_DATA_HOME=$HOME/.local/share kpackagetool5 --type Plasma/Applet --install package/org.kde.ktaskwidget
```

You can leave the stale snap-confined copy in place — plasmashell ignores it.

---

## 9. Uninstall

```sh
make remove
```

Equivalent to `kpackagetool5 --type Plasma/Applet --remove org.kde.ktaskwidget`. This removes the package directory from `~/.local/share/plasma/plasmoids/` and unregisters it from the widget picker.

The config (your tasks) is **not** removed automatically — it lives in `~/.config/plasma-org.kde.plasma.desktop-appletsrc` under the panel/desktop containment that hosted the widget. If you re-install later and add the widget back, your tasks will reappear. To wipe them, remove the widget from the panel before uninstalling, or manually edit the config file.
