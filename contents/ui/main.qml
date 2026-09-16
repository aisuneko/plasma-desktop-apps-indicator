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
            root.currentIndex = -1;
        }
        onCurrentDesktopChanged: {
            if (!changed)
                currentIndex = -1;
            changed = false;
        }
    }

    Layout.minimumWidth: stuff.implicitWidth
    Layout.minimumHeight: stuff.implicitHeight
    implicitWidth: stuff.implicitWidth
    implicitHeight: stuff.implicitHeight
    preferredRepresentation: fullRepresentation

    MouseArea {
        anchors.fill: parent
        onWheel: wheel => {
            if (root.currentIndex == -1)
                root.currentIndex = virtualDesktopInfo.desktopIds.findIndex(desktop => desktop === virtualDesktopInfo.currentDesktop);
            if (wheel.angleDelta.y > 0) { // Scroll up.
                if (root.currentIndex == 0)
                    return;
                root.currentIndex--;
            } else if (wheel.angleDelta.y < 0) { // Scroll down.
                if (root.currentIndex == virtualDesktopInfo.desktopIds.length - 1)
                    return;
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
        spacing: Kirigami.Units.smallSpacing

        Row {
            id: pinnedGroup
            spacing: Kirigami.Units.smallSpacing

            // visible: (pinnedGroupContainer.implicitWidth > 0) && (virtualDesktopInfo.numberOfDesktops !== 1)

            Rectangle {
                id: pinnedGroupBackground
                radius: 6
                color: Kirigami.Theme.alternateBackgroundColor
                border.width: 1
                border.color: Kirigami.Theme.alternateBackgroundColor
                opacity: 1
                implicitWidth: pinnedGroupContainer.implicitWidth + 2 * pinnedGroupBackground.padding
                implicitHeight: Math.max(pinnedGroupContainer.implicitHeight + 2 * pinnedGroupBackground.padding, stuff.implicitHeight)
                property real padding: Kirigami.Units.smallSpacing

                Row {
                    id: pinnedGroupContainer
                    anchors.centerIn: parent
                    spacing: Kirigami.Units.smallSpacing
                    Repeater {
                        id: pinnedGroupRepeater
                        model: TaskManager.TasksModel {
                            id: pinnedGroupModel
                            groupMode: TaskManager.TasksModel.GroupApplications
                            sortMode: TaskManager.TasksModel.SortDisabled
                        }
                        delegate: Item {
                            width: 24
                            height: 24
                            visible: model.IsOnAllVirtualDesktops

                            Kirigami.Icon {
                                anchors.fill: parent
                                source: model.decoration !== undefined ? model.decoration : "plasma-symbolic"
                                opacity: model.IsHidden === true ? 0.5 : 1
                            }

                            MouseArea {
                                anchors.fill: parent
                                propagateComposedEvents: true
                                onClicked: {
                                    pinnedGroupModel.requestActivate(pinnedGroupModel.index(index, 0));
                                    mouse.accepted = false;
                                }
                            }
                        }
                    }
                }
            }
        }

        Repeater {
            model: virtualDesktopInfo.desktopIds
            delegate: Row {
                id: desktopGroup
                property var desktopId: modelData
                implicitWidth: groupBackground.implicitWidth
                implicitHeight: groupBackground.implicitHeight

                Rectangle {
                    id: groupBackground
                    radius: 6
                    color: virtualDesktopInfo.currentDesktop === desktopGroup.desktopId ? Kirigami.Theme.highlightColor : "transparent"
                    border.width: 1
                    border.color: virtualDesktopInfo.currentDesktop === desktopGroup.desktopId ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                    opacity: virtualDesktopInfo.currentDesktop === desktopGroup.desktopId ? 1 : 0.75

                    implicitWidth: groupContainer.implicitWidth + 2 * groupBackground.padding
                    implicitHeight: Math.max(groupContainer.implicitHeight + 2 * groupBackground.padding, stuff.implicitHeight)
                    property real padding: Kirigami.Units.smallSpacing

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.currentIndex = virtualDesktopInfo.desktopIds.findIndex(desktop => desktop === desktopGroup.desktopId);
                            setCurrentDesktop(root.currentIndex);
                        }
                    }

                    Row {
                        id: groupContainer
                        anchors.centerIn: parent
                        spacing: Kirigami.Units.smallSpacing
                        Repeater {
                            model: TaskManager.TasksModel {
                                id: groupModel
                                virtualDesktop: desktopGroup.desktopId
                                filterByVirtualDesktop: true
                                filterByScreen: false
                                filterByActivity: false
                                groupMode: TaskManager.TasksModel.GroupApplications
                                sortMode: TaskManager.TasksModel.SortDisabled
                            }
                            delegate: Item {
                                width: 24
                                height: 24
                                visible: !model.IsOnAllVirtualDesktops || (model.IsOnAllVirtualDesktops && virtualDesktopInfo.numberOfDesktops === 1)

                                Kirigami.Icon {
                                    anchors.fill: parent
                                    source: model.decoration !== undefined ? model.decoration : "plasma-symbolic"
                                    opacity: model.IsHidden === true ? 0.5 : 1
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    propagateComposedEvents: true
                                    onClicked: {
                                        groupModel.requestActivate(groupModel.index(index, 0));
                                        mouse.accepted = false;
                                    }
                                }
                            }
                        }
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
            'arguments': [new DBus.int32(index + 1)]
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
                    'arguments': [new DBus.uint32(virtualDesktopInfo.numberOfDesktops), new DBus.string(''),]
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
                    'arguments': [new DBus.string(virtualDesktopInfo.currentDesktop)]
                });
            }
        },
        PlasmaCore.Action {
            text: i18nc("@action:inmenu widget context menu", "Configure Virtual Desktops…") // qmllint disable unqualified
            onTriggered: {
                if (Qt.platform.pluginName.includes("wayland"))
                    KCM.KCMLauncher.openSystemSettings("kcm_kwin_virtualdesktops");
                else
                    KCM.KCMLauncher.openSystemSettings("kcm_kwin_virtualdesktops_x11");
            }
        }
    ]
}
