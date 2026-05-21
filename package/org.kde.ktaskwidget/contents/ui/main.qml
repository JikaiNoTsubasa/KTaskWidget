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
        var normalized = normalizeOrder(parsed)
        taskListModel.clear()
        for (var i = 0; i < normalized.length; i++) {
            taskListModel.append(normalized[i])
        }
        recomputeDoneCount()
    }

    function normalizeOrder(arr) {
        var undone = []
        var done = []
        for (var i = 0; i < arr.length; i++) {
            if (arr[i].done) done.push(arr[i])
            else undone.push(arr[i])
        }
        return undone.concat(done)
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

    function newId() {
        return Date.now().toString(36) + Math.random().toString(36).slice(2, 6)
    }

    function firstDoneIndex() {
        for (var i = 0; i < taskListModel.count; i++) {
            if (taskListModel.get(i).done) return i
        }
        return taskListModel.count
    }

    function addTask(name) {
        var clean = (name || "").trim()
        if (clean.length === 0) return
        taskListModel.insert(firstDoneIndex(), {
            id: newId(),
            name: clean,
            done: false,
            created: new Date().toISOString()
        })
        recomputeDoneCount()
        saveQueued()
    }

    function moveTask(fromIdx, toIdx) {
        if (fromIdx === toIdx) return
        if (fromIdx < 0 || toIdx < 0) return
        if (fromIdx >= taskListModel.count || toIdx >= taskListModel.count) return
        taskListModel.move(fromIdx, toIdx, 1)
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
        var idx = -1
        for (var i = 0; i < taskListModel.count; i++) {
            if (taskListModel.get(i).id === id) { idx = i; break }
        }
        if (idx < 0) return
        var newDone = !taskListModel.get(idx).done
        taskListModel.setProperty(idx, "done", newDone)
        var targetIdx
        if (newDone) {
            targetIdx = taskListModel.count - 1
        } else {
            var firstDone = taskListModel.count
            for (var j = 0; j < taskListModel.count; j++) {
                if (j !== idx && taskListModel.get(j).done) { firstDone = j; break }
            }
            targetIdx = firstDone > idx ? firstDone - 1 : firstDone
        }
        if (targetIdx !== idx && targetIdx >= 0 && targetIdx < taskListModel.count) {
            taskListModel.move(idx, targetIdx, 1)
        }
        recomputeDoneCount()
        saveQueued()
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

}
