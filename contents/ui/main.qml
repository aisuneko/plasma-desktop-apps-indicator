import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.taskmanager as TaskManager
import org.kde.plasma.workspace.dbus as DBus
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

PlasmoidItem {
    id: root
    property int currentIndex: -1
    property bool changed: false

    TaskManager.VirtualDesktopInfo {
        id: virtualDesktopInfo
        onDesktopIdsChanged: {
            root.currentIndex = -1
        }
        onCurrentDesktopChanged: {
            if (!changed) currentIndex = -1;
            changed = false;
        }
    }

    Layout.minimumWidth: stuff.implicitWidth
    Layout.minimumHeight: stuff.implicitHeight
    preferredRepresentation: fullRepresentation

    MouseArea {
        anchors.fill: parent
        onWheel: wheel => {
            if (root.currentIndex == -1) root.currentIndex = virtualDesktopInfo.desktopIds.findIndex(desktop => desktop === virtualDesktopInfo.currentDesktop);
            if (wheel.angleDelta.y > 0) { // Scroll up.
                if (root.currentIndex == 0) return;
                root.currentIndex--;
            } else if (wheel.angleDelta.y < 0) { // Scroll down.
                if (root.currentIndex == virtualDesktopInfo.desktopIds.length - 1) return;
                root.currentIndex++;
            } else {
                return;
            }

            setCurrentDesktop(root.currentIndex);
        }
    }

    Flow {
        id: stuff
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing / 2

        Repeater {
            model: virtualDesktopInfo.desktopIds
            delegate: Rectangle {
                width: Kirigami.Theme.defaultFont.pointSize
                height: Kirigami.Theme.defaultFont.pointSize
                radius: width / 2

                color: virtualDesktopInfo.currentDesktop === modelData ? Kirigami.Theme.textColor : "transparent"

                border.color: Kirigami.Theme.textColor
                border.width: width * 0.05

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.currentIndex = index;
                        setCurrentDesktop(root.currentIndex);
                    }
                }
            }
        }
    }

    function setCurrentDesktop(index) {
        changed = true;
        DBus.SessionBus.asyncCall({
            'service': 'org.kde.KWin',
            'path': '/KWin',
            'iface': 'org.kde.KWin',
            'member': 'setCurrentDesktop',
            'signature': '(i)',
            'arguments': [
                new DBus.int32(index + 1)
            ]
        });
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18nc("@action:inmenu widget context menu", "Add Virtual Desktop") // qmllint disable unqualified
            icon.name: "list-add"
            onTriggered: {
                DBus.SessionBus.asyncCall({
                    'service': 'org.kde.KWin',
                    'path': '/VirtualDesktopManager',
                    'iface': 'org.kde.KWin.VirtualDesktopManager',
                    'member': 'createDesktop',
                    'signature': '(us)',
                    'arguments': [
                        new DBus.uint32(virtualDesktopInfo.numberOfDesktops),
                        new DBus.string(''),
                    ]
                });
            }
        },
        PlasmaCore.Action {
            text: i18nc("@action:inmenu widget context menu", "Remove Virtual Desktop") // qmllint disable unqualified
            icon.name: "list-remove"
            enabled: virtualDesktopInfo.desktopIds.length > 1
            onTriggered: {
                DBus.SessionBus.asyncCall({
                    'service': 'org.kde.KWin',
                    'path': '/VirtualDesktopManager',
                    'iface': 'org.kde.KWin.VirtualDesktopManager',
                    'member': 'removeDesktop',
                    'signature': '(s)',
                    'arguments': [
                        new DBus.string(virtualDesktopInfo.currentDesktop)
                    ]
                });
            }
        },
        PlasmaCore.Action {
            text: i18nc("@action:inmenu widget context menu", "Configure Virtual Desktops…") // qmllint disable unqualified
            onTriggered: {
                if (Qt.platform.pluginName.includes("wayland"))
                    KCM.KCMLauncher.openSystemSettings("kcm_kwin_virtualdesktops")
                else
                    KCM.KCMLauncher.openSystemSettings("kcm_kwin_virtualdesktops_x11")
            }
        }
    ]
}