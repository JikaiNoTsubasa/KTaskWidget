# KTaskWidget
Widget for Kubuntu (KDE Plasma 6) to manage daily tasks.

Target: **Ubuntu / Kubuntu 26.04 LTS, Plasma 6**. The Plasma 5 version (v0.1) is available in git history (commit `bf6289b`).

## Quick start

```sh
sudo apt install kpackagetool6 make zip
make install      # install or upgrade the widget
make restart      # only needed after an upgrade
```

Then right-click the panel → **Add Widgets…** → **Task Widget**.

To build a `.plasmoid` archive for "Install Widget from Local File…": `make package`.

## Documentation

- [docs/INSTALL.md](docs/INSTALL.md) — full build / install / upgrade / troubleshooting guide (in French)
- [docs/IMPLEMENTATION.md](docs/IMPLEMENTATION.md) — architecture and Plasma 6 port notes

# Description
Widget to be installed in Kubuntu Plasma and enabled from the menu "install from local" in Plasma.

The widget is an icon in a panel (or on the desktop). When clicking the icon, a popup opens:
- A toolbar with a + icon to create new tasks, a button to clear completed tasks, and a "close" icon on the right
- A list of tasks with a tickbox to mark the task as done, the name of the task, edit/delete buttons, and a drag handle to reorder

The app allows CRUD of tasks.

Tasks are saved in the Plasma configuration (`~/.config/plasma-org.kde.plasma.desktop-appletsrc`, key `tasksJson`) and reloaded when the widget starts.
