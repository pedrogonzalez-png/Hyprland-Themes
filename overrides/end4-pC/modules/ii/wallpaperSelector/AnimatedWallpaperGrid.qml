import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    property int columns: Config.options.wallpaperSelector.columns || 4
    property real previewCellAspectRatio: 4 / 3
    property real cellWidth: grid.cellWidth
    property real cellHeight: grid.cellHeight
    property var videos: []
    property string activePath: ""
    property string statusMessage: ""
    property bool loading: false
    property int currentIndex: 0
    readonly property string helper: String(Directories.home).replace(/^file:\/\//, "")
        + "/.config/quickshell/end4-pC/scripts/animated-picker.py"

    function refresh() {
        if (scanProcess.running) return
        loading = true
        statusMessage = "Carregando vídeos e miniaturas..."
        scanProcess.running = true
    }
    function moveSelection(delta) {
        if (root.videos.length === 0) return
        root.currentIndex = Math.max(0, Math.min(root.videos.length - 1, root.currentIndex + delta))
        grid.positionViewAtIndex(root.currentIndex, GridView.Contain)
    }
    function activateCurrent() {
        if (root.videos.length > root.currentIndex)
            applyVideo(root.videos[root.currentIndex].path)
    }
    function applyVideo(path) {
        if (!path || path.length === 0) return
        // [end4pc-native-animated-v3] Usa o switchwall.sh nativo via Wallpapers.apply.
        // Nao inicia mpvpaper pela segunda vez nem modifica os perfis salvos.
        // [end4pc-wallpaper-layout-switch-v2] Salvar antes da troca nativa.
        if (!WallpaperLayouts.prepareSwitch(path)) return
        Wallpapers.stopPreview()
        root.statusMessage = "Solicitando wallpaper ao sistema nativo..."
        Wallpapers.apply(path)
        root.activePath = path
        if (Config.options.wallpaperSelector.closeAfterSelection)
            GlobalStates.wallpaperSelectorOpen = false
    }

    Component.onCompleted: refresh()

    Process {
        id: scanProcess
        command: ["python3", root.helper, "scan"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(this.text)
                    if (!result.ok) {
                        root.statusMessage = result.error ?? "Falha ao atualizar vídeos"
                        return
                    }
                    root.videos = result.items ?? []
                    // [end4pc-animated-sync-v1]: a selecao do cache pode estar desatualizada.
                    const savedActive = result.active ?? ""
                    root.activePath = savedActive === String(Config.options.background.wallpaperPath ?? "")
                        ? savedActive : ""
                    root.statusMessage = root.videos.length === 0
                        ? "Pasta vazia: ~/Pictures/Wallpapers/Animated"
                        : root.videos.length + " vídeo(s) encontrado(s)"
                    if (!result.ffmpeg)
                        root.statusMessage += " — instale ffmpeg para miniaturas"
                } catch (e) {
                    root.statusMessage = "Erro ao ler galeria: " + e
                }
            }
        }
        onExited: (exitCode) => {
            root.loading = false
            if (exitCode !== 0 && root.statusMessage === "Carregando vídeos e miniaturas...")
                root.statusMessage = "Falha na leitura dos vídeos. Confira o log do Quickshell."
        }
    }

    Process {
        id: applyProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(this.text)
                    if (result.ok) {
                        root.activePath = result.path
                        // Atualiza a superficie Quickshell (camada acima do mpvpaper).
                        // confirmedPath/previewPath de Wallpapers sobrescrevem config.json.
                        Wallpapers.stopPreview()
                        Wallpapers.confirmedPath = ""
                        let thumbnail = ""
                        for (const video of root.videos) {
                            if (video.path === result.path) {
                                thumbnail = video.thumbnail ?? ""
                                break
                            }
                        }
                        Config.options.background.thumbnailPath = thumbnail
                        Config.options.background.wallpaperPath = result.path
                        WallpaperLayouts.activate(result.path)
                        root.statusMessage = "Animado aplicado no monitor " + result.monitor
                        if (Config.options.wallpaperSelector.closeAfterSelection)
                            GlobalStates.wallpaperSelectorOpen = false
                    } else {
                        root.statusMessage = "Falha: " + (result.error ?? "erro desconhecido")
                    }
                } catch (e) {
                    root.statusMessage = "Erro ao executar mpvpaper: " + e
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 18
            Layout.rightMargin: 18
            spacing: 8

            MaterialSymbol { text: "movie"; iconSize: 20 }
            StyledText {
                text: "Animated · " + root.statusMessage
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            RippleButton {
                implicitWidth: 36
                implicitHeight: 32
                buttonRadius: 16
                enabled: !root.loading
                onClicked: root.refresh()
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "refresh"
                    iconSize: 20
                }
                StyledToolTip { text: "Refresh / Atualizar vídeos" }
            }
        }

        // END4PC_ANIMATED_BOTTOM_STRIP_V1
        // Spacer flexível: empurra a galeria para perto do rodapé do seletor.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: grid.cellHeight + 32
            Layout.bottomMargin: 10
            clip: true
            // Uma fileira: os próximos vídeos continuam na horizontal, com rolagem.
            flow: GridView.FlowTopToBottom
            model: root.videos
            cellWidth: Math.min(270, width / Math.max(1, root.columns))
            cellHeight: cellWidth / root.previewCellAspectRatio + 26
            topMargin: 12
            leftMargin: 10
            rightMargin: 10
            ScrollBar.horizontal: StyledScrollBar {}

            delegate: Item {
                id: tile
                z: hovering ? 3 : 0
                required property var modelData
                required property int index
                width: grid.cellWidth
                height: grid.cellHeight
                readonly property bool chosen: root.activePath === modelData.path
                property bool hovering: false
                property string previewPath: ""
                property string requestedPath: ""

                onModelDataChanged: {
                    previewDelay.stop()
                    hovering = false
                    previewPath = ""
                }

                Timer {
                    id: previewDelay
                    interval: 260
                    repeat: false
                    onTriggered: {
                        if (!tile.hovering || previewProcess.running || !tile.modelData.path) return
                        tile.requestedPath = tile.modelData.path
                        previewProcess.command = ["python3", root.helper, "preview", tile.requestedPath]
                        previewProcess.running = true
                    }
                }

                Process {
                    id: previewProcess
                    stdout: StdioCollector {
                        onStreamFinished: {
                            try {
                                const reply = JSON.parse(this.text)
                                if (reply.ok && tile.modelData.path === tile.requestedPath)
                                    tile.previewPath = reply.path
                            } catch (e) {
                                console.warn("[AnimatedPreview] Resposta inesperada:", e)
                            }
                        }
                    }
                }

                Rectangle {
                    id: tileFrame
                    anchors.fill: parent
                    anchors.margins: 7
                    // Leve ampliação como no Caelestia; o GIF de hover permanece igual.
                    scale: tile.hovering ? 1.035 : 1.0
                    Behavior on scale {
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }
                    color: tile.chosen ? Appearance.colors.colSecondaryContainer
                        : Appearance.colors.colPrimaryContainer
                    radius: Appearance.rounding.normal
                    border.color: tile.chosen ? Appearance.colors.colPrimary
                        : Appearance.colors.colLayer0Border
                    border.width: tile.chosen ? 2 : 1
                    clip: true

                    Image {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: label.top
                        anchors.margins: 5
                        source: modelData.thumbnail ? "file://" + encodeURI(modelData.thumbnail)
                            .replace(/#/g, "%23").replace(/\?/g, "%3F") : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        sourceSize.width: 360
                    }
                    // Animação de ~2s gerada sob demanda com FFmpeg; nunca executa mpvpaper no hover.
                    // A miniatura JPG permanece visível enquanto o GIF ainda está sendo criado.
                    AnimatedImage {
                        id: hoverPreview
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: label.top
                        anchors.margins: 5
                        source: tile.hovering && tile.previewPath !== ""
                            ? "file://" + encodeURI(tile.previewPath).replace(/#/g, "%23").replace(/\?/g, "%3F")
                            : ""
                        fillMode: Image.PreserveAspectCrop
                        playing: tile.hovering
                        visible: tile.hovering && status === Image.Ready
                        cache: true
                    }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "movie"
                        visible: !modelData.thumbnail
                        iconSize: 42
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 9
                        width: 28
                        height: 28
                        radius: 14
                        color: Appearance.colors.colSecondaryContainer
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: tile.chosen ? "check" : "play_arrow"
                            iconSize: 19
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 9
                        radius: 9
                        width: previewText.implicitWidth + 15
                        height: 24
                        visible: tile.hovering
                        color: Appearance.colors.colSecondaryContainer
                        StyledText {
                            id: previewText
                            anchors.centerIn: parent
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSecondaryContainer
                            text: hoverPreview.status === Image.Ready && tile.previewPath !== ""
                                ? "PREVIEW" : "Carregando..."
                        }
                    }
                    StyledText {
                        id: label
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                        text: modelData.name
                        elide: Text.ElideMiddle
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        root.currentIndex = tile.index
                        tile.hovering = true
                        if (tile.previewPath === "") previewDelay.restart()
                    }
                    onExited: {
                        tile.hovering = false
                        previewDelay.stop()
                    }
                    onClicked: {
                        root.currentIndex = tile.index
                        root.applyVideo(tile.modelData.path)
                    }
                }
            }
        }
    }
}
