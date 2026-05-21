import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents

Item {
    id: fullRep

    property var api
    property var tasksModel

    Layout.preferredWidth: PlasmaCore.Units.gridUnit * 18
    Layout.preferredHeight: PlasmaCore.Units.gridUnit * 22
    Layout.minimumWidth: PlasmaCore.Units.gridUnit * 14
    Layout.minimumHeight: PlasmaCore.Units.gridUnit * 12

    property bool addingTask: false

    onAddingTaskChanged: {
        if (addingTask) {
            newTaskField.text = ""
            Qt.callLater(function () { newTaskField.forceActiveFocus() })
        }
    }

    function submitNewTask() {
        var value = newTaskField.text
        console.log("[ktaskwidget] submitNewTask called, text=" + JSON.stringify(value)
                    + " api=" + (fullRep.api ? "present" : "NULL"))
        if (!fullRep.api) {
            console.warn("[ktaskwidget] fullRep.api is null — cannot add task")
            return
        }
        if (value.trim().length === 0) return
        fullRep.api.addTask(value)
        newTaskField.text = ""
        newTaskField.forceActiveFocus()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: PlasmaCore.Units.smallSpacing
        spacing: PlasmaCore.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: PlasmaCore.Units.smallSpacing

            PlasmaComponents.ToolButton {
                icon.name: "list-add"
                onClicked: fullRep.addingTask = !fullRep.addingTask
                PlasmaComponents.ToolTip.text: i18n("Add task")
                PlasmaComponents.ToolTip.visible: hovered
                PlasmaComponents.ToolTip.delay: 500
            }

            PlasmaComponents.ToolButton {
                icon.name: "edit-clear-list"
                enabled: fullRep.api && fullRep.api.doneCount > 0
                onClicked: fullRep.api.clearDone()
                PlasmaComponents.ToolTip.text: i18n("Clear completed tasks (%1)", fullRep.api ? fullRep.api.doneCount : 0)
                PlasmaComponents.ToolTip.visible: hovered
                PlasmaComponents.ToolTip.delay: 500
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: i18n("Tasks")
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            PlasmaComponents.ToolButton {
                icon.name: "window-close"
                onClicked: plasmoid.expanded = false
                PlasmaComponents.ToolTip.text: i18n("Close")
                PlasmaComponents.ToolTip.visible: hovered
                PlasmaComponents.ToolTip.delay: 500
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: fullRep.addingTask
            spacing: PlasmaCore.Units.smallSpacing

            PlasmaComponents.TextField {
                id: newTaskField
                Layout.fillWidth: true
                placeholderText: i18n("New task…")
                onAccepted: fullRep.submitNewTask()
                Keys.onReturnPressed: fullRep.submitNewTask()
                Keys.onEnterPressed: fullRep.submitNewTask()
                Keys.onEscapePressed: fullRep.addingTask = false
            }

            PlasmaComponents.ToolButton {
                icon.name: "dialog-ok"
                enabled: newTaskField.text.trim().length > 0
                onClicked: fullRep.submitNewTask()
                PlasmaComponents.ToolTip.text: i18n("Add")
                PlasmaComponents.ToolTip.visible: hovered
                PlasmaComponents.ToolTip.delay: 500
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: PlasmaCore.Theme.textColor
            opacity: 0.15
            visible: fullRep.tasksModel && fullRep.tasksModel.count > 0
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !fullRep.tasksModel || fullRep.tasksModel.count === 0
            text: i18n("No tasks yet.\nClick + to add one.")
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            opacity: 0.6
            wrapMode: Text.WordWrap
        }

        ListView {
            id: taskList
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: fullRep.tasksModel && fullRep.tasksModel.count > 0
            clip: true
            spacing: 0
            model: fullRep.tasksModel
            delegate: TaskRow {
                width: taskList.width
                api: fullRep.api
            }
        }
    }
}
