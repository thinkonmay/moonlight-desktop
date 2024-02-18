import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Window 2.2
import QtQuick.Controls.Material 2.2

import ComputerManager 1.0
import StreamingPreferences 1.0
import SystemProperties 1.0
import SdlGamepadKeyNavigation 1.0

ApplicationWindow {
    id: window
    visible: true
    width: 1280
    height: 600

    Component.onCompleted: {
        if (SystemProperties.usesMaterial3Theme) {
            Material.background = "#303030"
        }
    }

    visibility: {
        if (SystemProperties.hasDesktopEnvironment) {
            if (StreamingPreferences.uiDisplayMode == StreamingPreferences.UI_WINDOWED) return "Windowed"
            else if (StreamingPreferences.uiDisplayMode == StreamingPreferences.UI_MAXIMIZED) return "Maximized"
            else if (StreamingPreferences.uiDisplayMode == StreamingPreferences.UI_FULLSCREEN) return "FullScreen"
        } else {
            return "FullScreen"
        }
    }
  
    property bool initialized: false
    StackView {
        id: stackView
        initialItem: initialView
        anchors.fill: parent
        focus: true

        onCurrentItemChanged: {
            // Ensure focus travels to the next view when going back
            if (currentItem) {
                currentItem.forceActiveFocus()
            }
        }

        Keys.onEscapePressed: {
            if (depth > 1) {
                goBack()
            }
            else {
                quitConfirmationDialog.open()
            }
        }

        Keys.onBackPressed: {
            if (depth > 1) {
                goBack()
            }
            else {
                quitConfirmationDialog.open()
            }
        }

        Keys.onMenuPressed: {
            settingsButton.clicked()
        }

        // This is a keypress we've reserved for letting the
        // SdlGamepadKeyNavigation object tell us to show settings
        // when Menu is consumed by a focused control.
        Keys.onHangupPressed: {
            settingsButton.clicked()
        }
    }

}
