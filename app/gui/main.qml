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

    
    StackView {
        id: stackView
        initialItem: initialView
        session: Session

        onActivated: {

        }


    }

}
