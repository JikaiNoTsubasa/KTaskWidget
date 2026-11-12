import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: fullRep

    property var api
    property var tasksModel

    Layout.preferredWidth: Kirigami.Units.gridUnit * 27
    Layout.preferredHeight: Kirigami.Units.gridUnit * 33
    Layout.minimumWidth: Kirigami.Units.gridUnit * 21
    Layout.minimumHeight: Kirigami.Units.gridUnit * 18

    property bool addingTask: false

    onAddingTaskChanged: {
        if (addingTask) {
            newTaskField.text = ""
            Qt.callLater(function () { newTaskField.forceActiveFocus() })
        }
    }

    function submitNewTask() {
        var value = newTaskField.text
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
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.ToolButton {
                icon.name: "list-add"
                onClicked: fullRep.addingTask = !fullRep.addingTask
                QQC2.ToolTip.text: i18n("Add task")
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: 500
            }

            PlasmaComponents.ToolButton {
                icon.name: "edit-clear-list"
                enabled: fullRep.api && fullRep.api.doneCount > 0
                onClicked: fullRep.api.clearDone()
                QQC2.ToolTip.text: i18n("Clear completed tasks (%1)", fullRep.api ? fullRep.api.doneCount : 0)
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: 500
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: i18n("Tasks")
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            PlasmaComponents.ToolButton {
                icon.name: "window-close"
                onClicked: fullRep.api.expanded = false
                QQC2.ToolTip.text: i18n("Close")
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: 500
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: fullRep.addingTask
            spacing: Kirigami.Units.smallSpacing

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
                QQC2.ToolTip.text: i18n("Add")
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: 500
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Kirigami.Theme.textColor
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

            moveDisplaced: Transition {
                NumberAnimation { property: "y"; duration: 150; easing.type: Easing.OutQuad }
            }
            displaced: Transition {
                NumberAnimation { property: "y"; duration: 150; easing.type: Easing.OutQuad }
            }
        }
    }
}
