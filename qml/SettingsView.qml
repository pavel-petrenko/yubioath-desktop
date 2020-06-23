import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2
import QtGraphicalEffects 1.0

Flickable {

    id: settingsPanel
    objectName: 'settingsView'
    contentWidth: app.width
    contentHeight: content.implicitHeight + 32

    readonly property int dynamicWidth: 648
    readonly property int dynamicMargin: 32

    ScrollBar.vertical: ScrollBar {
        width: 8
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        hoverEnabled: true
        z: 2
    }
    boundsBehavior: Flickable.StopAtBounds

    Keys.onEscapePressed: navigator.home()

    property string title: qsTr("")

    ColumnLayout {
        width: settingsPanel.contentWidth
        id: content
        spacing: 0

        StyledExpansionContainer {
            title: qsTr("Current device")

            SettingsPanelCurrentDevice {}
        }

        StyledExpansionContainer {
            title: qsTr("General")

            SettingsPanelAppearance {}
            SettingsPanelCustomReader {}
            SettingsPanelSystemTray {}
            SettingsPanelClearPasswords {}
        }
    }
}
