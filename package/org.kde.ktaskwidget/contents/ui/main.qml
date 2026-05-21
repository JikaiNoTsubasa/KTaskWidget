import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore

Item {
    id: root

    Plasmoid.preferredRepresentation: Plasmoid.compactRepresentation
    Plasmoid.switchWidth: PlasmaCore.Units.gridUnit * 12
    Plasmoid.switchHeight: PlasmaCore.Units.gridUnit * 8

    Plasmoid.compactRepresentation: PlasmaCore.IconItem {
        source: "view-task"
        active: compactMouse.containsMouse
        MouseArea {
            id: compactMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: plasmoid.expanded = !plasmoid.expanded
        }
    }

    Plasmoid.fullRepresentation: FullRepresentation {
        api: root
        tasksModel: taskListModel
    }

    ListModel { id: taskListModel }

    property int doneCount: 0

    function recomputeDoneCount() {
        var n = 0
        for (var i = 0; i < taskListModel.count; i++) {
            if (taskListModel.get(i).done) n++
        }
        doneCount = n
    }

    function clearDone() {
        for (var i = taskListModel.count - 1; i >= 0; i--) {
            if (taskListModel.get(i).done) {
                taskListModel.remove(i)
            }
        }
        recomputeDoneCount()
        saveQueued()
    }

    Timer {
        id: saveDebounce
        interval: 500
        repeat: false
        onTriggered: root.saveNow()
    }

    Component.onCompleted: loadTasks()

    function loadTasks() {
        var raw = plasmoid.configuration.tasksJson || "[]"
        var parsed
        try { parsed = JSON.parse(raw) } catch (e) { parsed = [] }
        if (!Array.isArray(parsed)) parsed = []
        taskListModel.clear()
        var sorted = sortTasks(parsed)
        for (var i = 0; i < sorted.length; i++) {
            taskListModel.append(sorted[i])
        }
        recomputeDoneCount()
    }

    function saveQueued() {
        saveDebounce.restart()
    }

    function saveNow() {
        var arr = []
        for (var i = 0; i < taskListModel.count; i++) {
            var t = taskListModel.get(i)
            arr.push({
                id: t.id,
                name: t.name,
                done: t.done,
                created: t.created
            })
        }
        plasmoid.configuration.tasksJson = JSON.stringify(arr)
    }

    function sortTasks(arr) {
        return arr.slice().sort(function (a, b) {
            if (a.done !== b.done) return a.done ? 1 : -1
            if (a.created < b.created) return -1
            if (a.created > b.created) return 1
            return 0
        })
    }

    function newId() {
        return Date.now().toString(36) + Math.random().toString(36).slice(2, 6)
    }

    function addTask(name) {
        console.log("[ktaskwidget] root.addTask called: " + JSON.stringify(name))
        var clean = (name || "").trim()
        if (clean.length === 0) return
        taskListModel.append({
            id: newId(),
            name: clean,
            done: false,
            created: new Date().toISOString()
        })
        reSort()
        recomputeDoneCount()
        saveQueued()
    }

    function renameTask(id, name) {
        var clean = (name || "").trim()
        if (clean.length === 0) return
        for (var i = 0; i < taskListModel.count; i++) {
            if (taskListModel.get(i).id === id) {
                taskListModel.setProperty(i, "name", clean)
                saveQueued()
                return
            }
        }
    }

    function toggleDone(id) {
        for (var i = 0; i < taskListModel.count; i++) {
            if (taskListModel.get(i).id === id) {
                taskListModel.setProperty(i, "done", !taskListModel.get(i).done)
                reSort()
                recomputeDoneCount()
                saveQueued()
                return
            }
        }
    }

    function removeTask(id) {
        for (var i = 0; i < taskListModel.count; i++) {
            if (taskListModel.get(i).id === id) {
                taskListModel.remove(i)
                recomputeDoneCount()
                saveQueued()
                return
            }
        }
    }

    function reSort() {
        var arr = []
        for (var i = 0; i < taskListModel.count; i++) {
            var t = taskListModel.get(i)
            arr.push({
                id: t.id,
                name: t.name,
                done: t.done,
                created: t.created
            })
        }
        var sorted = sortTasks(arr)
        taskListModel.clear()
        for (var j = 0; j < sorted.length; j++) {
            taskListModel.append(sorted[j])
        }
    }
}
