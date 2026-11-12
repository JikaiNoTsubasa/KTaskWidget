import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: row

    property var api
    property int dragSourceIndex: index
    property bool editing: false

    width: ListView.view ? ListView.view.width : 0
    height: contentRect.height

    Rectangle {
        id: contentRect

        anchors.horizontalCenter: row.horizontalCenter
        anchors.verticalCenter: row.verticalCenter

        width: row.width
        height: layout.implicitHeight + Kirigami.Units.smallSpacing * 2
        radius: 3
        color: gripArea.drag.active
               ? Kirigami.Theme.alternateBackgroundColor
               : "transparent"
        opacity: gripArea.drag.active ? 0.9 : 1.0
        z: gripArea.drag.active ? 10 : 0

        Drag.active: gripArea.drag.active
        Drag.source: row
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        states: State {
            name: "dragging"
            when: gripArea.drag.active
            ParentChange { target: contentRect; parent: row.ListView.view }
            AnchorChanges {
                target: contentRect
                anchors.horizontalCenter: undefined
                anchors.verticalCenter: undefined
            }
        }

        RowLayout {
            id: layout
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            anchors.topMargin: Kirigami.Units.smallSpacing
            anchors.bottomMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Item {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    text: "⋮⋮"
                    opacity: 0.55
                    font.pixelSize: Kirigami.Units.iconSizes.small
                }

                MouseArea {
                    id: gripArea
                    anchors.fill: parent
                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: contentRect
                    drag.axis: Drag.YAxis
                }
            }

            PlasmaComponents.CheckBox {
                id: checkbox
                checked: model.done
                onToggled: row.api.toggleDone(model.id)
            }

            PlasmaComponents.Label {
                id: nameLabel
                Layout.fillWidth: true
                visible: !row.editing
                text: model.name
                elide: Text.ElideRight
                font.strikeout: model.done
                opacity: model.done ? 0.6 : 1.0

                MouseArea {
                    id: nameHover
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    onDoubleClicked: row.startEdit()
                }

                QQC2.ToolTip.text: model.name
                QQC2.ToolTip.visible: nameHover.containsMouse && nameLabel.truncated
                QQC2.ToolTip.delay: 500
            }

            PlasmaComponents.TextField {
                id: nameField
                Layout.fillWidth: true
                visible: row.editing
                text: model.name
                onAccepted: row.commitEdit()
                Keys.onEscapePressed: row.cancelEdit()
                onActiveFocusChanged: {
                    if (!activeFocus && row.editing) {
                        row.commitEdit()
                    }
                }
            }

            PlasmaComponents.ToolButton {
                icon.name: row.editing ? "dialog-ok" : "document-edit"
                onClicked: row.editing ? row.commitEdit() : row.startEdit()
                QQC2.ToolTip.text: row.editing ? i18n("Save") : i18n("Edit")
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: 500
            }

            PlasmaComponents.ToolButton {
                icon.name: "edit-delete"
                onClicked: row.api.removeTask(model.id)
                QQC2.ToolTip.text: i18n("Delete")
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: 500
            }
        }
    }

    DropArea {
        anchors.fill: parent
        onEntered: function (dragEvent) {
            var src = dragEvent.source
            if (!src || src === row) return
            if (typeof src.dragSourceIndex === "undefined") return
            row.api.moveTask(src.dragSourceIndex, row.dragSourceIndex)
        }
    }

    function startEdit() {
        nameField.text = model.name
        row.editing = true
        nameField.forceActiveFocus()
        nameField.selectAll()
    }

    function commitEdit() {
        if (!row.editing) return
        var value = nameField.text.trim()
        if (value.length > 0 && value !== model.name) {
            row.api.renameTask(model.id, value)
        }
        row.editing = false
    }

    function cancelEdit() {
        nameField.text = model.name
        row.editing = false
    }
}
