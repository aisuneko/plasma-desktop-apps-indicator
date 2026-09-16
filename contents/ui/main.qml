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

    component CornerIndicator: Canvas {
        property real radius: 0
        property real borderWidth: 1

        onRadiusChanged: requestPaint()
        onVisibleChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            const inset = borderWidth;
            const inner = Math.max(radius - inset, 0);
            ctx.beginPath();
            ctx.moveTo(inset + inner, inset);
            ctx.arcTo(width - inset, inset, width - inset, height - inset, inner);
            ctx.arcTo(width - inset, height - inset, inset, height - inset, inner);
            ctx.arcTo(inset, height - inset, inset, inset, inner);
            ctx.arcTo(inset, inset, width - inset, inset, inner);
            ctx.clip();

            ctx.beginPath();
            ctx.moveTo(width, height / 2);
            ctx.lineTo(width, height);
            ctx.lineTo(width / 2, height);
            ctx.closePath();
            ctx.fillStyle = Kirigami.Theme.highlightColor;
            ctx.fill();
        }
    }

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
            delegate: Item {
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

                        property int attentionCount: 0
                        property bool attention: attentionCount > 0

                        Repeater {
                            id: groupRepeater
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

                                // TasksModel's internal filter lets windows demanding attention bypass virtual desktop filter
                                // Gate on actual desktop membership here
                                readonly property bool attention: model.IsDemandingAttention === true
                                    && model.IsOnAllVirtualDesktops !== true
                                    && (model.VirtualDesktops === undefined
                                        || model.VirtualDesktops.indexOf(desktopGroup.desktopId) !== -1)

                                property bool counted: false

                                onAttentionChanged: syncCount()
                                Component.onCompleted: syncCount()
                                Component.onDestruction: if (counted) groupContainer.attentionCount--

                                function syncCount() {
                                    if (counted !== attention) {
                                        groupContainer.attentionCount += (attention ? 1 : -1);
                                        counted = attention;
                                    }
                                }

                                visible: (!model.IsOnAllVirtualDesktops || virtualDesktopInfo.numberOfDesktops === 1) && !(model.IsDemandingAttention === true && model.VirtualDesktops !== undefined && model.VirtualDesktops.indexOf(desktopGroup.desktopId) === -1)

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

                CornerIndicator {
                    anchors.fill: groupBackground
                    visible: groupContainer.attention
                    radius: groupBackground.radius
                    borderWidth: groupBackground.border.width
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
