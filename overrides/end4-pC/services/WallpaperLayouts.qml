pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// Perfis de organizacao por wallpaper (arquivo separado do config.json principal).
// Salva somente propriedades de layout, visibilidade e conteudo de widgets de imagem.
Singleton {
    id: root

    property bool initialized: false
    property bool storageReady: false
    property bool restoring: false
    property string activePath: ""
    property string lastSnapshot: ""
    // [end4pc-wallpaper-layout-switch-v2]
    property string pendingPath: ""
    property bool safeToAutosave: true
    property int restoreRetries: 0
    // [end4pc-autosave-protected-v3] Edicoes de usuario em restauracoes incompletas.
    // A referencia nao e o JSON do tema: e somente o estado VISIVEL estabilizado.
    property string protectedBaseline: ""
    property bool protectedEditingReady: false
    property string protectedCandidate: ""

    readonly property var widgetKeys: [
        "clock", "weather", "calendar", "worldClock", "media", "visualizer",
        "resources", "userCard", "todo", "notes", "timers", "images",
        "customImage", "imageCard", "imageCard2", "imageCard3",
        "imageCard4", "imageCard5", "imageCard6", "sticker", "customText"
    ]
    readonly property var layoutFields: [
        "enable", "placementStrategy", "x", "y", "z", "sizeMode", "size",
        "cardWidth", "cardHeight", "height", "width", "shape", "rotation",
        "vertical", "ringSize"
    ]
    readonly property var imageKeys: [
        "customImage", "imageCard", "imageCard2", "imageCard3",
        "imageCard4", "imageCard5", "imageCard6", "sticker"
    ]

    function cleanPath(value) {
        let s = String(value ?? "").trim()
        if (s.startsWith("file://")) {
            try { s = decodeURIComponent(s.substring(7)) }
            catch (e) { s = s.substring(7) }
        }
        return s
    }

    function capture() {
        const result = {}
        const entries = Config.options.background.widgets
        for (const key of root.widgetKeys) {
            const item = entries[key]
            if (!item) continue
            const state = {}
            for (const prop of root.layoutFields) {
                const v = item[prop]
                if (typeof v === "string" || typeof v === "boolean"
                        || (typeof v === "number" && Number.isFinite(v))) {
                    state[prop] = v
                }
            }
            if (root.imageKeys.includes(key) && typeof item.path === "string") {
                state.path = item.path
            }
            result[key] = state
        }
        return result
    }

    function restore(layout) {
        if (!layout || typeof layout !== "object") return
        root.restoreRetries = 0
        root.safeToAutosave = false
        root.protectedEditingReady = false
        root.protectedBaseline = ""
        root.protectedCandidate = ""
        protectedArmTimer.stop()
        root.applyLayout(layout)
    }

    function applyLayout(layout) {
        const entries = Config.options.background.widgets
        root.restoring = true
        for (const key of root.widgetKeys) {
            const item = entries[key]
            const state = layout[key]
            if (!item || !state || typeof state !== "object") continue
            for (const field of Object.keys(state)) {
                if (!root.layoutFields.includes(field)
                        && !(field === "path" && root.imageKeys.includes(key))) continue
                if (typeof item[field] === "undefined") continue
                if (item[field] !== state[field]) item[field] = state[field]
            }
        }
        // Aguarda as escritas do Config.qml e as atualizacoes do layout.
        finishRestoreTimer.restart()
    }

    function profilesCopy() {
        const obj = layoutsData.profiles
        if (!obj || typeof obj !== "object" || Array.isArray(obj)) return {}
        return Object.assign({}, obj)
    }

    function saveProfile(path, snapshot) {
        if (!path || !root.storageReady || !snapshot) return
        const profiles = root.profilesCopy()
        profiles[path] = snapshot
        layoutsData.profiles = profiles // Atribuicao dispara JsonAdapter.adapterUpdated.
    }

    // Modo seguro para casos em que Qt/Config.qml nao consegue restaurar
    // exatamente todos os campos. Em vez de sobrescrever TODO o perfil com
    // o estado parcialmente restaurado, persiste APENAS campos alterados
    // depois de uma linha de base estavel, e SOMENTE no perfil ativo.
    function saveProtectedEdits(now) {
        if (!root.protectedEditingReady || root.restoring || root.pendingPath !== "") return
        if (!root.activePath || !root.storageReady) return
        let baseline
        try { baseline = JSON.parse(root.protectedBaseline) }
        catch (e) { return }
        const profiles = root.profilesCopy()
        const saved = profiles[root.activePath]
        if (!saved || typeof saved !== "object") return
        const updated = Object.assign({}, saved)
        let changes = 0
        for (const key of root.widgetKeys) {
            const before = baseline[key]
            const current = now[key]
            if (!before || !current) continue
            let nextWidget = null
            for (const field of Object.keys(current)) {
                if (!root.layoutFields.includes(field)
                        && !(field === "path" && root.imageKeys.includes(key))) continue
                if (!Object.prototype.hasOwnProperty.call(before, field)) continue
                if (JSON.stringify(before[field]) === JSON.stringify(current[field])) continue
                if (!nextWidget) nextWidget = Object.assign({}, saved[key] || {})
                nextWidget[field] = current[field]
                changes++
            }
            if (nextWidget) updated[key] = nextWidget
        }
        if (changes > 0) {
            root.saveProfile(root.activePath, updated)
            root.lastSnapshot = JSON.stringify(updated)
            console.log("[WallpaperLayouts] Edicao protegida salva no perfil:",
                        root.activePath, "campos:", changes)
        }
        root.protectedBaseline = JSON.stringify(now)
    }

    function initialize() {
        if (root.initialized || !root.storageReady || !Config.ready) return
        const current = root.cleanPath(Config.options.background.wallpaperPath)
        if (!current) return
        root.activePath = current
        const profiles = root.profilesCopy()
        if (profiles[current]) {
            root.restore(profiles[current])
            root.lastSnapshot = JSON.stringify(profiles[current])
        } else {
            const snapshot = root.capture()
            root.lastSnapshot = JSON.stringify(snapshot)
            root.saveProfile(current, snapshot)
        }
        root.initialized = true
        console.log("[WallpaperLayouts] Iniciado para", current)
    }

    // Chamada ANTES de iniciar o switchwall.sh. Salva o perfil de origem
    // antes que o Qt/QML possa atualizar algum widget na transicao.
    // Nao sobrescreve um perfil durante restauracao incompleta.
    function prepareSwitch(path) {
        const nextPath = root.cleanPath(path)
        if (!nextPath) return false
        if (!root.initialized) root.initialize()
        if (!root.initialized) {
            console.warn("[WallpaperLayouts] Perfis ainda nao carregados; selecao bloqueada")
            return false
        }
        if (nextPath === root.activePath) return true
        if (root.pendingPath !== "") {
            console.warn("[WallpaperLayouts] Aguarde troca anterior:", root.pendingPath)
            return false
        }
        if (root.restoring) {
            console.warn("[WallpaperLayouts] Aguarde a restauracao anterior")
            return false
        }
        if (root.safeToAutosave) {
            const snapshot = root.capture()
            root.lastSnapshot = JSON.stringify(snapshot)
            root.saveProfile(root.activePath, snapshot)
        } else {
            console.warn("[WallpaperLayouts] Perfil de origem protegido contra sobrescrita por restauracao incompleta")
        }
        root.pendingPath = nextPath
        switchTimeout.restart()
        console.log("[WallpaperLayouts] Troca solicitada:", root.activePath, "->", nextPath)
        return true
    }

    // Executado quando o wallpaperPath nativo de fato mudar. NUNCA captura
    // o layout anterior aqui: a tela pode ja conter o layout do outro tema.
    function activate(path) {
        const nextPath = root.cleanPath(path)
        if (!nextPath || !Config.ready || !root.storageReady) return
        if (!root.initialized) root.initialize()
        if (!root.initialized) return
        if (nextPath === root.activePath) return
        if (root.pendingPath && root.pendingPath !== nextPath) {
            console.warn("[WallpaperLayouts] Ignorando caminho intermediario:", nextPath)
            return
        }

        const previous = root.activePath
        const profiles = root.profilesCopy()
        let nextLayout = profiles[nextPath]
        if (!nextLayout) {
            // Wallpaper novo: copia a ULTIMA fotografia segura do tema anterior.
            // Nunca copia um estado parcialmente restaurado ou misturado.
            const baseline = root.lastSnapshot || JSON.stringify(root.capture())
            nextLayout = JSON.parse(baseline)
            root.saveProfile(nextPath, nextLayout)
        }
        root.pendingPath = ""
        switchTimeout.stop()
        root.activePath = nextPath
        root.lastSnapshot = JSON.stringify(nextLayout)
        root.restore(nextLayout)
        console.log("[WallpaperLayouts] Perfil restaurando:", previous, "->", nextPath)
    }

    // Falha do wallpaper nativo: nao deixa o sistema preso em troca pendente.
    Timer {
        id: switchTimeout
        interval: 12000
        repeat: false
        onTriggered: {
            if (root.pendingPath !== "") {
                console.warn("[WallpaperLayouts] Wallpaper nao confirmou a troca:", root.pendingPath)
                root.pendingPath = ""
            }
        }
    }

    // A interface tem alguns segundos para estabilizar apos uma restauracao
    // incompleta. So mudancas POSTERIORES a esse momento sao consideradas
    // edicoes do usuario; o JSON existente continua intacto ate la.
    Timer {
        id: protectedArmTimer
        interval: 4800
        repeat: false
        onTriggered: {
            if (root.safeToAutosave || root.restoring || root.pendingPath !== ""
                    || !root.initialized || !Config.ready) return
            root.protectedBaseline = JSON.stringify(root.capture())
            root.protectedCandidate = ""
            root.protectedEditingReady = true
            console.log("[WallpaperLayouts] Edicoes automaticas protegidas ativadas:", root.activePath)
        }
    }

    Timer {
        id: finishRestoreTimer
        interval: 1800
        repeat: false
        onTriggered: {
            const actual = JSON.stringify(root.capture())
            if (actual === root.lastSnapshot) {
                root.restoring = false
                root.safeToAutosave = true
                root.protectedEditingReady = false
                root.protectedBaseline = ""
                root.protectedCandidate = ""
                protectedArmTimer.stop()
                console.log("[WallpaperLayouts] Restauracao conferida:", root.activePath)
            } else if (root.restoreRetries < 2) {
                root.restoreRetries++
                console.warn("[WallpaperLayouts] Restauracao incompleta, repetindo tentativa", root.restoreRetries)
                root.applyLayout(JSON.parse(root.lastSnapshot))
                finishRestoreTimer.restart()
            } else {
                root.restoring = false
                root.safeToAutosave = false
                root.protectedEditingReady = false
                root.protectedCandidate = ""
                // CRITICO: nunca grava TODO o layout parcialmente restaurado.
                // Permite mais tarde apenas edicoes realizadas no tema ativo.
                protectedArmTimer.restart()
                console.warn("[WallpaperLayouts] PERFIL PROTEGIDO: restauracao nao conferiu:", root.activePath)
            }
        }
    }

    // Autossalvamento para arrastes, redimensionamentos e enable/disable.
    Timer {
        interval: 1200
        repeat: true
        running: root.initialized
        onTriggered: {
            if (root.restoring || root.pendingPath !== "" || !Config.ready) return
            const now = root.capture()
            const encoded = JSON.stringify(now)
            if (root.safeToAutosave) {
                if (encoded !== root.lastSnapshot) {
                    root.lastSnapshot = encoded
                    root.saveProfile(root.activePath, now)
                }
            } else if (root.protectedEditingReady) {
                // Exige duas leituras identicas antes de salvar edicao protegida.
                // Assim um ajuste transitorio de Qt nao vira perfil permanente.
                if (encoded === root.protectedBaseline) {
                    root.protectedCandidate = ""
                } else if (encoded !== root.protectedCandidate) {
                    root.protectedCandidate = encoded
                } else {
                    root.saveProtectedEdits(now)
                    root.protectedCandidate = ""
                }
            }
        }
    }

    Timer {
        id: writeTimer
        interval: 350
        repeat: false
        onTriggered: profileFile.writeAdapter()
    }

    FileView {
        id: profileFile
        path: `${Directories.shellConfig}/wallpaper_widget_layouts.json`
        watchChanges: false
        onAdapterUpdated: writeTimer.restart()
        onLoaded: {
            root.storageReady = true
            Qt.callLater(root.initialize)
        }
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) {
                root.storageReady = true
                Qt.callLater(root.initialize)
            } else {
                console.warn("[WallpaperLayouts] Nao foi possivel ler perfis:", error)
            }
        }
        onSaveFailed: (error) => console.warn("[WallpaperLayouts] Falha ao salvar:", error)
        JsonAdapter {
            id: layoutsData
            property int version: 1
            property var profiles: ({})
        }
    }

    Connections {
        target: Config
        function onReadyChanged() { Qt.callLater(root.initialize) }
    }
    Connections {
        target: Config.options.background
        function onWallpaperPathChanged() {
            if (!root.initialized) Qt.callLater(root.initialize)
            else Qt.callLater(() => root.activate(Config.options.background.wallpaperPath))
        }
    }
    Component.onCompleted: Qt.callLater(root.initialize)
}
