import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents

Item {
    id: row

    property var api

    implicitHeight: layout.implicitHeight + PlasmaCore.Units.smallSpacing * 2

    property bool editing: false

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.leftMargin: PlasmaCore.Units.smallSpacing
        anchors.rightMargin: PlasmaCore.Units.smallSpacing
        anchors.topMargin: PlasmaCore.Units.smallSpacing
        anchors.bottomMargin: PlasmaCore.Units.smallSpacing
        spacing: PlasmaCore.Units.smallSpacing

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

            PlasmaComponents.ToolTip.text: model.name
            PlasmaComponents.ToolTip.visible: nameHover.containsMouse && nameLabel.truncated
            PlasmaComponents.ToolTip.delay: 500
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
            PlasmaComponents.ToolTip.text: row.editing ? i18n("Save") : i18n("Edit")
            PlasmaComponents.ToolTip.visible: hovered
            PlasmaComponents.ToolTip.delay: 500
        }

        PlasmaComponents.ToolButton {
            icon.name: "edit-delete"
            onClicked: row.api.removeTask(model.id)
            PlasmaComponents.ToolTip.text: i18n("Delete")
            PlasmaComponents.ToolTip.visible: hovered
            PlasmaComponents.ToolTip.delay: 500
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
