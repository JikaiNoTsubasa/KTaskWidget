# KTaskWidget — Implementation Documentation

A Plasma 6 panel widget for managing daily tasks, built as a pure QML/JS plasmoid (no C++).

## 1. What it is

A Plasma 6 applet that lives in a panel (or on the desktop) as an icon. Clicking the icon opens a popup with a small toolbar (add task / close) and a checkable list of tasks. Tasks persist across Plasma restarts.

Target environment: KDE Plasma 6 (KF6 / Qt 6), Ubuntu / Kubuntu 26.04 LTS. Tested on Plasma 6.6.6. The Plasma 5 version (v0.1) is in git history; see [Plasma 6 port notes](#7-plasma-6-port-notes).

## 2. Architecture overview

```
KTaskWidget/
├── README.md
├── Makefile                                 build / install / dev targets
├── .gitignore
├── docs/INSTALL.md                          build / install guide (French)
├── docs/IMPLEMENTATION.md                   this file
└── package/
    └── org.kde.ktaskwidget/                 the plasmoid package
        ├── metadata.json                    Plasma 6 package manifest
        └── contents/
            ├── config/
            │   └── main.xml                 declares the `tasksJson` config key
            └── ui/
                ├── main.qml                 Plasmoid root: model, CRUD, save logic
                ├── FullRepresentation.qml   popup UI (toolbar + list)
                └── TaskRow.qml              per-task row delegate
```

A plasmoid is a directory with a strict layout — `metadata.json` at its root, `contents/ui/` for QML, `contents/config/` for KConfig schemas. The directory is either installed in-place via `kpackagetool6` or zipped into a `.plasmoid` archive for Plasma's GUI install flow.

### Runtime model

```
                ┌─────────────────────────┐
                │   plasmashell / panel   │
                └───────────┬─────────────┘
                            │ instantiates
                            ▼
   ┌─────────────────────────────────────────────────┐
   │  main.qml  (root PlasmoidItem, id "root")       │
   │  ─ ListModel { id: tasksModel }                 │
   │  ─ addTask / renameTask / toggleDone / removeTask│
   │  ─ Timer "saveDebounce" (500 ms)                │
   │  ─ load/save against Plasmoid.configuration     │
   └─────┬─────────────────────────────┬─────────────┘
         │ compactRepresentation         │ fullRepresentation
         ▼                               ▼
   ┌──────────────┐               ┌─────────────────────────┐
   │ Kirigami.Icon│ click toggles │ FullRepresentation.qml  │
   │ "view-task"  │ root.expanded │  ─ toolbar              │
   │ + MouseArea  │               │  ─ new-task TextField   │
   └──────────────┘               │  ─ ListView ──► TaskRow │
                                  └─────────────────────────┘
```

`FullRepresentation` and each `TaskRow` are wired to `main.qml` via two properties: `api` (a reference to the root `PlasmoidItem`, so they can call `addTask` / `renameTask` / `toggleDone` / `removeTask`) and `tasksModel` (the shared `ListModel`). No signal-relaying scaffolding — children call the API directly.

### Data flow

1. **Load** — `Component.onCompleted` calls `loadTasks()`, which reads `Plasmoid.configuration.tasksJson`, parses it, sorts, and populates `tasksModel`.
2. **Mutate** — UI calls `addTask` / `renameTask` / `toggleDone` / `removeTask` on the root. Each mutates `tasksModel`, optionally re-sorts (`addTask` and `toggleDone` do), and calls `saveQueued()`.
3. **Save** — `saveQueued()` restarts a 500 ms debounce `Timer`. On fire, `saveNow()` serializes the model back to JSON and assigns it to `Plasmoid.configuration.tasksJson`. KConfig flushes to disk on its own cadence.

The debounce coalesces bursts (e.g., rapid checkbox toggling) into a single write, so the config file isn't touched on every keystroke.

## 3. File responsibilities

### `package/org.kde.ktaskwidget/metadata.json`
Plasma 6 package manifest (JSON, read through `KPluginMetaData`). The relevant keys are:

| Key | Purpose |
| --- | --- |
| `KPlugin.Id = org.kde.ktaskwidget` | Unique plugin ID. **Must match the package directory name** and must not change, otherwise existing panel instances lose their config. |
| `KPackageStructure = Plasma/Applet` | Marks it as an applet (replaces `ServiceTypes` / `X-KDE-ServiceTypes`). |
| `X-Plasma-API-Minimum-Version = 6.0` | Required: without it Plasma 6 refuses to load the applet as a Plasma 5 leftover. |
| `KPlugin.FormFactors = [desktop, horizontal, vertical]` | Allows placement on desktop and in horizontal/vertical panels. |
| `KPlugin.Icon = view-task` | Icon in the "Add Widgets" picker, also used by the compact representation via `Plasmoid.icon`. |
| `KPlugin.Name`, `Description`, `Version`, `Authors`, `License`, `Category` | Shown in the picker and in "About this widget". |

The entry point is implicit in Plasma 6: `contents/ui/main.qml` (the former `X-Plasma-MainScript` key is no longer needed). The QML-only nature is also implicit (the former `X-Plasma-API=declarativeappletscript` is gone).

### `package/org.kde.ktaskwidget/contents/config/main.xml`
KConfigXT schema. Declares a single key `tasksJson` (string, default `[]`) in group `General`. This automatically materializes as `Plasmoid.configuration.tasksJson` in QML — read and write it like any QML property. KConfig serializes it under `~/.config/plasma-org.kde.plasma.desktop-appletsrc`.

### `package/org.kde.ktaskwidget/contents/ui/main.qml`
The plasmoid root. Responsibilities:

- Is a `PlasmoidItem` (mandatory root type in Plasma 6).
- Declares `compactRepresentation` (a `Kirigami.Icon` showing `Plasmoid.icon`, with a `MouseArea` that toggles `root.expanded`) and `fullRepresentation` (a `FullRepresentation { api: root; tasksModel: taskListModel }`).
- Sets `preferredRepresentation: compactRepresentation` so the widget always shows as an icon (never inline-expanded).
- Sets `switchWidth` and `switchHeight` so the popup degrades to icon-only in narrow panels.
- Holds `ListModel { id: tasksModel }` — the canonical list of tasks at runtime.
- Implements `loadTasks`, `saveNow`, `saveQueued`, `sortTasks`, `newId`, `addTask`, `renameTask`, `toggleDone`, `removeTask`, `reSort`.

### `package/org.kde.ktaskwidget/contents/ui/FullRepresentation.qml`
The popup. Pure presentation. Takes:

- `api` — root reference for CRUD calls.
- `tasksModel` — the ListView model.

Contains the toolbar (`+` button toggles `addingTask`, close button sets `api.expanded = false`, i.e. the root `PlasmoidItem.expanded`), the inline new-task `TextField` (visible when `addingTask` is true), a separator rule, an empty-state label, and the `ListView` of tasks. Sets `Layout.preferredWidth/Height` so the popup gets a sensible default size.

### `package/org.kde.ktaskwidget/contents/ui/TaskRow.qml`
Per-task delegate. Takes:

- `api` — root reference for CRUD calls.

Renders a row with: checkbox bound to `model.done`, name label (strikethrough when done, double-click to edit), a `TextField` for inline editing (visible during `editing` state), an edit/save toggle button, and a delete button. Edit commits on `Enter` and on focus loss; cancels on `Escape`.

## 4. Persistence schema

Tasks are stored as a JSON-stringified array under the config key `tasksJson`. Each entry:

```json
{
  "id": "<base36-time + 4 random chars>",
  "name": "Buy groceries",
  "done": false,
  "created": "2026-05-21T10:00:00.000Z"
}
```

Sort order applied after every mutation: undone tasks first, then done tasks, each group ordered by `created` ascending. The model is fully rebuilt on each `reSort()` — fine at our scale (typical task lists are well under 100 entries).

On disk this lives in `~/.config/plasma-org.kde.plasma.desktop-appletsrc` under a `[Containments][<n>][Applets][<m>][Configuration][General]` section. The exact section indices depend on which panel the widget is placed in — KConfig manages it.

## 5. Installation

### For end users (GUI install)

1. Build the archive: `make package` (produces `ktaskwidget.plasmoid`).
2. In Plasma: right-click the desktop or a panel → **Add Widgets** → **Get New Widgets** → **Install Widget from Local File** → select `ktaskwidget.plasmoid`.
3. Drag the **Task Widget** entry from the widget picker onto a panel.

### For development (direct kpackagetool install)

```sh
make install     # kpackagetool6 -t Plasma/Applet -i (or -u) package/org.kde.ktaskwidget
make upgrade     # for subsequent updates
make remove      # uninstall
make reinstall   # remove + install
make restart     # systemctl --user restart plasma-plasmashell.service
```

After `install`, the widget appears in the "Add Widgets" picker without needing a `plasma-restart`. After `upgrade`, plasmashell must be restarted (`make restart`) to pick up QML changes — re-adding the widget reuses the cached QML components. See [INSTALL.md](INSTALL.md) for the full procedure.

## 6. Development workflow

Fastest inner loop:

```sh
make dev   # plasmoidviewer -a package/org.kde.ktaskwidget
```

`plasmoidviewer` (package `plasma-sdk`) launches a standalone window hosting just the plasmoid, no panel involvement. QML changes are picked up on each relaunch. Persistence still works — `plasmoidviewer` uses the same KConfig store as the panel.

When changing `metadata.json`, `kpackagetool6 -u` is required for `plasmoidviewer` to see the new metadata (or just run `make dev` against the source directory, which re-reads it on each launch).

Recommended manual smoke test after any change:

1. `make dev` — popup opens, "No tasks yet" appears on a clean install.
2. Click `+`, type a task, press Enter → task appears in the list.
3. Tick the checkbox → strikethrough applied, task moves to the bottom.
4. Double-click the name → inline editor opens, edit, Enter → name updates.
5. Click the trash icon → task disappears.
6. Close `plasmoidviewer`, relaunch → all surviving state is restored.
7. `make package && make install` — verify the panel install path works too.

## 7. Plasma 6 port notes

v0.2 ports the widget from Plasma 5 (KF5 / Qt 5) to Plasma 6 (KF6 / Qt 6). Changes:

| Plasma 5 | Plasma 6 | Where |
| --- | --- | --- |
| `metadata.desktop` | `metadata.json` (`KPlugin` object, `KPackageStructure`, `X-Plasma-API-Minimum-Version`) | package root |
| Root `Item` + attached `Plasmoid.compactRepresentation` / `fullRepresentation` / `preferredRepresentation` / `switchWidth` / `switchHeight` | Root `PlasmoidItem` with plain properties of the same names | `main.qml` |
| `plasmoid.expanded` | `PlasmoidItem.expanded` (`root.expanded`, `api.expanded` from children) | `main.qml`, `FullRepresentation.qml` |
| `plasmoid.configuration` | `Plasmoid.configuration` (attached, capital P) | `main.qml` |
| `PlasmaCore.Units.*` | `Kirigami.Units.*` | all QML |
| `PlasmaCore.Theme.*` | `Kirigami.Theme.*` | all QML |
| `PlasmaCore.IconItem` | `Kirigami.Icon` | `main.qml` |
| `PlasmaComponents.ToolTip.*` attached | `QQC2.ToolTip.*` attached (`import QtQuick.Controls as QQC2`) | all QML |
| Versioned imports (`QtQuick 2.15`, `org.kde.plasma.components 3.0`…) | Unversioned imports | all QML |
| `kpackagetool5`, `kquitapp5`/`kstart5` | `kpackagetool6`, `systemctl --user restart plasma-plasmashell.service` | `Makefile` |

Unchanged on purpose: plugin ID, `contents/config/main.xml`, the `tasksJson` schema. Consequently an applet instance already placed on a panel under Plasma 5 keeps its tasks after the upgrade.

Upgrade gotcha: `kpackagetool6` does not recognise a package directory that only contains `metadata.desktop`, so `--upgrade` fails with "Plugin … is not installed". `make install` detects this case and deletes the stale Plasma 5 copy before installing.

## 8. Known limitations

- **Persistence path is not `~/.ktaskwidget.json`.** The original README implied a literal hidden dotfile in `$HOME`. Pure-QML file writes are blocked in plasmashell (Qt disables `XMLHttpRequest` PUT to `file://` URLs by default for security), and the alternatives (shelling out via `Plasma5Support.DataSource`, or shipping a C++ FileIO plugin) were rejected. Tasks live in `~/.config/plasma-org.kde.plasma.desktop-appletsrc` instead — still hidden, still in `$HOME`, but inside the standard Plasma config store. **Update the README to match.**
- **Plasma 6 only.** Since v0.2 the package no longer loads on Plasma 5. Check out the v0.1 commit (`bf6289b`) for Plasma 5.
- **No automated tests.** Plasma widgets are inherently visual; the manual smoke test above is the contract.
- **Save debounce is 500 ms.** A plasmashell crash within that window loses the most recent edit. Acceptable trade-off for the write-coalescing benefit.
- **No multi-device sync, due dates, priorities, categories, or reminders.** v1 is minimal CRUD by design.
- **No confirmation on delete.** A misclick removes a task irrevocably. Add an undo affordance in a future iteration if needed.

## 9. Extending

A few likely future directions and where they'd plug in:

- **Configuration page** (sort order, font size, max visible tasks): add `contents/config/config.qml` and a per-page `contents/ui/configGeneral.qml`. The XML schema in `contents/config/main.xml` is the source of truth for both.
- **Tray-icon mode** (system-tray rather than panel applet): add `X-Plasma-NotificationAreaCategory` to `metadata.json` and adjust `X-KDE-FormFactors`.
- **Notifications / due-date alerts**: add a `due` field to the task schema and a `Timer`, or use `org.kde.notification` (KF6 exposes `Notification` to QML, no C++ needed).
