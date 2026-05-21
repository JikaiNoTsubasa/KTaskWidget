# KTaskWidget — Implementation Documentation

A Plasma 5 panel widget for managing daily tasks, built as a pure QML/JS plasmoid (no C++).

## 1. What it is

A Plasma 5 applet that lives in a panel (or on the desktop) as an icon. Clicking the icon opens a popup with a small toolbar (add task / close) and a checkable list of tasks. Tasks persist across Plasma restarts.

Target environment: KDE Plasma 5 (KF5 / Qt 5). Tested layout against Plasma 5.27 conventions. **Not** ported to Plasma 6 — see [Known limitations](#7-known-limitations).

## 2. Architecture overview

```
KTaskWidget/
├── README.md
├── Makefile                                 build / install / dev targets
├── .gitignore
├── docs/IMPLEMENTATION.md                   this file
└── package/
    └── org.kde.ktaskwidget/                 the plasmoid package
        ├── metadata.desktop                 KDE service manifest
        └── contents/
            ├── config/
            │   └── main.xml                 declares the `tasksJson` config key
            └── ui/
                ├── main.qml                 Plasmoid root: model, CRUD, save logic
                ├── FullRepresentation.qml   popup UI (toolbar + list)
                └── TaskRow.qml              per-task row delegate
```

A plasmoid is a directory with a strict layout — `metadata.desktop` at its root, `contents/ui/` for QML, `contents/config/` for KConfig schemas. The directory is either installed in-place via `kpackagetool5` or zipped into a `.plasmoid` archive for Plasma's GUI install flow.

### Runtime model

```
                ┌─────────────────────────┐
                │   plasmashell / panel   │
                └───────────┬─────────────┘
                            │ instantiates
                            ▼
   ┌─────────────────────────────────────────────────┐
   │  main.qml  (root Item with id "root")           │
   │  ─ ListModel { id: tasksModel }                 │
   │  ─ addTask / renameTask / toggleDone / removeTask│
   │  ─ Timer "saveDebounce" (500 ms)                │
   │  ─ load/save against Plasmoid.configuration     │
   └─────┬─────────────────────────────┬─────────────┘
         │ Plasmoid.compactRepresentation│ Plasmoid.fullRepresentation
         ▼                               ▼
   ┌──────────────┐               ┌─────────────────────────┐
   │ IconItem     │ click toggles │ FullRepresentation.qml  │
   │ "view-task"  │ Plasmoid.     │  ─ toolbar              │
   │ + MouseArea  │ expanded      │  ─ new-task TextField   │
   └──────────────┘               │  ─ ListView ──► TaskRow │
                                  └─────────────────────────┘
```

`FullRepresentation` and each `TaskRow` are wired to `main.qml` via two properties: `api` (a reference to the root Item, so they can call `addTask` / `renameTask` / `toggleDone` / `removeTask`) and `tasksModel` (the shared `ListModel`). No signal-relaying scaffolding — children call the API directly.

### Data flow

1. **Load** — `Component.onCompleted` calls `loadTasks()`, which reads `plasmoid.configuration.tasksJson`, parses it, sorts, and populates `tasksModel`.
2. **Mutate** — UI calls `addTask` / `renameTask` / `toggleDone` / `removeTask` on the root. Each mutates `tasksModel`, optionally re-sorts (`addTask` and `toggleDone` do), and calls `saveQueued()`.
3. **Save** — `saveQueued()` restarts a 500 ms debounce `Timer`. On fire, `saveNow()` serializes the model back to JSON and assigns it to `plasmoid.configuration.tasksJson`. KConfig flushes to disk on its own cadence.

The debounce coalesces bursts (e.g., rapid checkbox toggling) into a single write, so the config file isn't touched on every keystroke.

## 3. File responsibilities

### `package/org.kde.ktaskwidget/metadata.desktop`
KDE service manifest. The required keys are:

| Key | Purpose |
| --- | --- |
| `X-KDE-PluginInfo-Name=org.kde.ktaskwidget` | Unique plugin ID. **Must match the package directory name.** |
| `X-Plasma-API=declarativeappletscript` | Declares this as a QML-only plasmoid (no C++). |
| `X-Plasma-MainScript=ui/main.qml` | Entry point relative to `contents/`. |
| `ServiceTypes=Plasma/Applet`, `X-KDE-ServiceTypes=Plasma/Applet` | Marks it as an applet (vs. data-engine, runner, etc.). |
| `X-KDE-FormFactors=desktop,horizontal,vertical` | Allows placement on desktop and in horizontal/vertical panels. |
| `Icon=view-task` | Default icon shown in the "Add Widgets" picker. |

`.desktop` files are parsed strictly — do not add inline comments on key-value lines.

### `package/org.kde.ktaskwidget/contents/config/main.xml`
KConfigXT schema. Declares a single key `tasksJson` (string, default `[]`) in group `General`. This automatically materializes as `plasmoid.configuration.tasksJson` in QML — read and write it like any QML property. KConfig serializes it under `~/.config/plasma-org.kde.plasma.desktop-appletsrc`.

### `package/org.kde.ktaskwidget/contents/ui/main.qml`
The plasmoid root. Responsibilities:

- Declares `Plasmoid.compactRepresentation` (a `PlasmaCore.IconItem` with a `MouseArea` that toggles `plasmoid.expanded`) and `Plasmoid.fullRepresentation` (a `FullRepresentation { api: root; tasksModel: tasksModel }`).
- Sets `Plasmoid.preferredRepresentation: compactRepresentation` so the widget always shows as an icon (never inline-expanded).
- Sets `Plasmoid.switchWidth` and `Plasmoid.switchHeight` so the popup degrades to icon-only in narrow panels.
- Holds `ListModel { id: tasksModel }` — the canonical list of tasks at runtime.
- Implements `loadTasks`, `saveNow`, `saveQueued`, `sortTasks`, `newId`, `addTask`, `renameTask`, `toggleDone`, `removeTask`, `reSort`.

### `package/org.kde.ktaskwidget/contents/ui/FullRepresentation.qml`
The popup. Pure presentation. Takes:

- `api` — root reference for CRUD calls.
- `tasksModel` — the ListView model.

Contains the toolbar (`+` button toggles `addingTask`, close button sets `plasmoid.expanded = false`), the inline new-task `TextField` (visible when `addingTask` is true), a separator rule, an empty-state label, and the `ListView` of tasks. Sets `Layout.preferredWidth/Height` so the popup gets a sensible default size.

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
make install     # kpackagetool5 -t Plasma/Applet -i package/org.kde.ktaskwidget
make upgrade     # for subsequent updates
make remove      # uninstall
make reinstall   # remove + install
```

After `install`, the widget appears in the "Add Widgets" picker without needing a `plasma-restart`. After `upgrade`, you typically need to remove the widget from the panel and re-add it (or `kquitapp5 plasmashell && kstart5 plasmashell`) to pick up QML changes.

## 6. Development workflow

Fastest inner loop:

```sh
make dev   # plasmoidviewer -a package/org.kde.ktaskwidget
```

`plasmoidviewer` launches a standalone window hosting just the plasmoid, no panel involvement. QML changes are picked up on each relaunch. Persistence still works — `plasmoidviewer` uses the same KConfig store as the panel.

When changing `metadata.desktop`, `kpackagetool5 -u` is required for `plasmoidviewer` to see the new metadata (or just run `make dev` against the source directory, which re-reads it on each launch).

Recommended manual smoke test after any change:

1. `make dev` — popup opens, "No tasks yet" appears on a clean install.
2. Click `+`, type a task, press Enter → task appears in the list.
3. Tick the checkbox → strikethrough applied, task moves to the bottom.
4. Double-click the name → inline editor opens, edit, Enter → name updates.
5. Click the trash icon → task disappears.
6. Close `plasmoidviewer`, relaunch → all surviving state is restored.
7. `make package && make install` — verify the panel install path works too.

## 7. Known limitations

- **Persistence path is not `~/.ktaskwidget.json`.** The original README implied a literal hidden dotfile in `$HOME`. Pure-QML file writes are blocked in plasmashell (Qt disables `XMLHttpRequest` PUT to `file://` URLs by default for security), and the alternatives (shelling out via `Plasma5Support.DataSource`, or shipping a C++ FileIO plugin) were rejected. Tasks live in `~/.config/plasma-org.kde.plasma.desktop-appletsrc` instead — still hidden, still in `$HOME`, but inside the standard Plasma config store. **Update the README to match.**
- **No Plasma 6 port.** Plasma 6 uses `metadata.json` instead of `metadata.desktop`, Qt 6 / KF6 imports (`org.kde.plasma.plasmoid 6.0`), and renamed plugin info keys. Porting is straightforward but out of scope for v1.
- **No automated tests.** Plasma widgets are inherently visual; the manual smoke test above is the contract.
- **Save debounce is 500 ms.** A plasmashell crash within that window loses the most recent edit. Acceptable trade-off for the write-coalescing benefit.
- **No multi-device sync, due dates, priorities, categories, or reminders.** v1 is minimal CRUD by design.
- **No confirmation on delete.** A misclick removes a task irrevocably. Add an undo affordance in a future iteration if needed.

## 8. Extending

A few likely future directions and where they'd plug in:

- **Configuration page** (sort order, font size, max visible tasks): add `contents/config/config.qml` and a per-page `contents/ui/configGeneral.qml`. The XML schema in `contents/config/main.xml` is the source of truth for both.
- **Tray-icon mode** (system-tray rather than panel applet): add `X-Plasma-NotificationAreaCategory` to `metadata.desktop` and adjust `X-KDE-FormFactors`.
- **Notifications / due-date alerts**: add a `due` field to the task schema and a `PlasmaCore.DataSource` polling on a `Timer`, calling `KNotification` via a small C++ plugin (no pure-QML API for notifications in Plasma 5).
- **Plasma 6 port**: rename `metadata.desktop` → `metadata.json`, bump QML imports, replace `org.kde.plasma.plasmoid 2.0` with `6.0`, replace `PlasmaCore.Units` with the `Kirigami.Units` equivalents, and replace `plasmoid.expanded` with `Plasmoid.expanded`. The `Plasmoid.configuration` persistence approach carries over unchanged.
