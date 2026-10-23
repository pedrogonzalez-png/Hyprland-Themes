pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Guia de atalhos PT-BR / EN integrado ao Dashboard do end4-pC.
// Lê os atalhos reais do serviço HyprlandKeybinds (não altera keybinds.lua).
Item {
    id: root
    property string language: "pt"
    property string category: "all"
    property string query: ""

    function t(pt, en) { return language === "pt" ? pt : en }

    function categoryOf(section, description) {
        const prefix = String(description).split(":")[0].toLowerCase().trim()
        const sec = String(section).toLowerCase()
        if (prefix === "app" || sec.includes("app")) return "apps"
        if (prefix === "window" || sec.includes("window")) return "windows"
        if (prefix === "workspace" || sec.includes("workspace")) return "workspaces"
        if (prefix === "media" || sec.includes("media")) return "media"
        if (prefix === "utilities" || prefix === "recorder" || sec.includes("utilit")) return "tools"
        if (prefix === "screen" || sec.includes("screen")) return "screen"
        if (prefix === "session" || sec.includes("session")) return "system"
        if (prefix === "shell" || sec.includes("shell")) return "shell"
        return "other"
    }

    readonly property var categories: [
        { id: "all", pt: "Todos", en: "All" },
        { id: "apps", pt: "Aplicativos", en: "Apps" },
        { id: "windows", pt: "Janelas", en: "Windows" },
        { id: "workspaces", pt: "Áreas de trabalho", en: "Workspaces" },
        { id: "shell", pt: "Interface", en: "Shell" },
        { id: "tools", pt: "Ferramentas", en: "Utilities" },
        { id: "media", pt: "Mídia", en: "Media" },
        { id: "screen", pt: "Tela", en: "Screen" },
        { id: "system", pt: "Sistema", en: "System" },
        { id: "other", pt: "Outros", en: "Other" }
    ]

    function categoryName(id) {
        const c = categories.find(v => v.id === id)
        return c ? (language === "pt" ? c.pt : c.en) : id
    }

    function prettyCombo(mods, key) {
        const pretty = String(key || "").replace(/^code:/, "Código ")
            .replace(/^mouse:272$/, "Mouse esquerdo")
            .replace(/^mouse:273$/, "Mouse direito")
            .replace(/^mouse:274$/, "Mouse central")
            .replace(/^Slash$/, "/")
            .replace(/^Period$/, ".")
            .replace(/^Return$/, "Enter")
            .replace(/^Page_Down$/, "PgDn")
            .replace(/^Page_Up$/, "PgUp")
        const values = (mods || []).map(m => {
            const x = String(m).toUpperCase()
            if (x === "SUPER" || x === "SUPER_L" || x === "SUPER_R") return "Super"
            if (x === "CTRL") return "Ctrl"
            if (x === "SHIFT") return "Shift"
            if (x === "ALT") return "Alt"
            return m
        })
        if (pretty !== "") values.push(pretty)
        return values.join(" + ")
    }

    // Tradução das descrições presentes no keybinds.lua do usuário.
    function translatedDescription(raw) {
        if (language === "en") {
            if (raw === "Configurações do end4-pC") return "end4-pC settings"
            if (raw === "Abrir Dashboard end4-pC") return "Open end4-pC dashboard"
            return raw
        }
        const dict = {
            "Shell: Toggle overview": "Interface: abrir/fechar visão geral",
            "Shell: Toggle right sidebar": "Interface: abrir/fechar barra lateral direita",
            "Shell: Toggle cheatsheet": "Interface: abrir/fechar guia de atalhos",
            "Shell: Toggle on-screen keyboard": "Interface: teclado virtual",
            "Shell: Toggle media controls": "Interface: controles de mídia",
            "Shell: Toggle widget overlay": "Interface: mostrar/ocultar widgets",
            "Shell: Toggle session menu": "Interface: menu da sessão",
            "Shell: Toggle bar": "Interface: mostrar/ocultar barra",
            "Shell: Change wallpaper": "Interface: trocar papel de parede",
            "Shell: Random wallpaper": "Interface: papel de parede aleatório",
            "Shell: Toggle light/dark mode": "Interface: alternar claro/escuro",
            "Shell: Restart widgets": "Interface: reiniciar widgets",
            "Shell: Cycle panel family": "Interface: alternar família de painéis",
            "Utilities: Clipboard history >> clipboard": "Ferramentas: histórico da área de transferência",
            "Utilities: Emoji >> clipboard": "Ferramentas: copiar emoji",
            "Utilities: Screen snip": "Ferramentas: capturar região da tela",
            "Utilities: Google Lens": "Ferramentas: pesquisar imagem com Lens",
            "Utilities: Character recognition >> clipboard": "Ferramentas: extrair texto da tela (OCR)",
            "Utilities: Translate screen content": "Ferramentas: traduzir conteúdo da tela",
            "Utilities: Pick color #RRGGBB >> clipboard": "Ferramentas: selecionar cor",
            "Utilities: Record region (no sound)": "Ferramentas: gravar região sem áudio",
            "Utilities: Record screen (with sound)": "Ferramentas: gravar tela com áudio",
            "Utilities: Screenshot >> clipboard": "Ferramentas: captura para área de transferência",
            "Utilities: Screenshot >> clipboard & file": "Ferramentas: captura para arquivo e área de transferência",
            "Utilities: Generate AI summary for selected text": "Ferramentas: resumir texto selecionado com IA",
            "Screen: Zoom out": "Tela: diminuir zoom",
            "Screen: Zoom in": "Tela: aumentar zoom",
            "Media: Next track": "Mídia: próxima faixa",
            "Media: Previous track": "Mídia: faixa anterior",
            "Media: Play/pause media": "Mídia: reproduzir/pausar",
            "Media: Toggle mute": "Mídia: silenciar/ativar som",
            "Media: Toggle mic": "Mídia: silenciar/ativar microfone",
            "Window: Move": "Janela: mover",
            "Window: Resize": "Janela: redimensionar",
            "Window: Close": "Janela: fechar",
            "Window: Forcefully zap a window": "Janela: forçar fechamento",
            "Window: Float/Tile": "Janela: alternar flutuante/mosaico",
            "Window: Maximize": "Janela: maximizar",
            "Window: Fullscreen": "Janela: tela cheia",
            "Window: Fullscreen spoof": "Janela: simular tela cheia",
            "Window: Pin": "Janela: manter sempre visível",
            "Window: Send to scratchpad": "Janela: enviar para área especial",
            "Workspace: Toggle scratchpad": "Área de trabalho: mostrar/ocultar área especial",
            "Session: Lock": "Sistema: bloquear sessão",
            "Session: Sleep": "Sistema: suspender",
            "Session: Shut down": "Sistema: desligar",
            "App: Terminal": "Aplicativos: terminal",
            "App: File manager": "Aplicativos: gerenciador de arquivos",
            "App: Browser": "Aplicativos: navegador",
            "App: Code editor": "Aplicativos: editor de código",
            "App: Office software": "Aplicativos: suíte de escritório",
            "App: Text editor": "Aplicativos: editor de texto",
            "App: Volume mixer": "Aplicativos: mixer de volume",
            "App: Settings app": "Aplicativos: configurações",
            "App: Task manager": "Aplicativos: gerenciador de tarefas",
            "Recorder: Save replay": "Gravação: salvar replay",
            "Configurações do end4-pC": "Configurações do end4-pC",
            "Abrir Dashboard end4-pC": "Abrir Dashboard end4-pC"
        }
        if (dict[raw] !== undefined) return dict[raw]
        const variable = [
            ["Window: Focus ", "Janela: focar "],
            ["Window: Move ", "Janela: mover "],
            ["Window: Send to workspace ", "Janela: enviar para área "],
            ["Workspace: Focus ", "Área de trabalho: acessar "]
        ]
        for (const pair of variable) if (raw.startsWith(pair[0])) return pair[1] + raw.slice(pair[0].length)
        return raw
    }

    readonly property var allBinds: {
        const list = []
        const seen = ({})
        function walk(node, parentGroup) {
            if (!node) return
            const group = String(node.name || parentGroup || "Shell")
            const binds = node.keybinds || []
            for (const bind of binds) {
                if (!bind.comment) continue
                const combo = root.prettyCombo(bind.mods, bind.key)
                const desc = String(bind.comment)
                const ident = combo + ":" + desc
                if (seen[ident]) continue
                seen[ident] = true
                list.push({ combo: combo, description: desc, category: root.categoryOf(group, desc) })
            }
            for (const child of (node.children || [])) walk(child, group)
        }
        walk(HyprlandKeybinds.keybinds, "Shell")
        // Alguns atalhos personalizados do usuário não têm campo description.
        const extras = [
            { combo: "Super + Alt + ↑", category: "apps", description: "Rofi dashboard", pt: "Abrir painel Rofi", en: "Open Rofi dashboard" },
            { combo: "Super + Alt + V", category: "apps", description: "btop", pt: "Abrir btop", en: "Open btop" },
            { combo: "Super + Alt + C", category: "apps", description: "tty-clock", pt: "Abrir relógio no Kitty", en: "Open terminal clock" },
            { combo: "Super + A", category: "apps", description: "Gaming stats", pt: "Abrir contador de horas de jogos", en: "Open gaming time tracker" },
            { combo: "Super + Alt + ↓", category: "shell", description: "Dashboard", pt: "Abrir Dashboard do end4-pC", en: "Open end4-pC dashboard" },
            { combo: "Super + /", category: "shell", description: "Shortcuts", pt: "Abrir este guia", en: "Open this shortcut guide" }
        ]
        for (const extra of extras) {
            // Se o serviço já encontrou uma tecla equivalente, não repetir.
            const normalized = s => s.toLowerCase().replace(/\s/g, "").replace("down", "↓").replace("up", "↑")
            if (!list.some(v => normalized(v.combo) === normalized(extra.combo))) list.unshift(extra)
        }
        return list
    }

    readonly property var filteredBinds: {
        const term = root.query.toLocaleLowerCase().trim()
        return allBinds.filter(item => {
            if (root.category !== "all" && item.category !== root.category) return false
            const content = [item.combo, item.description, item.pt || "", item.en || "", root.translatedDescription(item.description), root.categoryName(item.category)].join(" ").toLocaleLowerCase()
            return term === "" || content.includes(term)
        })
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                StyledText {
                    text: root.t("Guia de atalhos", "Keyboard shortcuts")
                    font.pixelSize: 27
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                }
                StyledText {
                    text: root.t("Seus atalhos do Hyprland • Super + / para abrir", "Your Hyprland shortcuts • Super + / to open")
                    font.pixelSize: 12
                    color: Appearance.colors.colSubtext
                }
            }
            Repeater {
                model: ["pt", "en"]
                delegate: Rectangle {
                    id: langChip
                    required property string modelData
                    implicitWidth: 64
                    implicitHeight: 36
                    radius: 18
                    color: root.language === modelData ? Appearance.colors.colPrimary : Appearance.colors.colLayer1
                    border.width: root.language === modelData ? 0 : 1
                    border.color: Appearance.colors.colPrimary
                    StyledText {
                        anchors.centerIn: parent
                        text: langChip.modelData === "pt" ? "PT-BR" : "EN"
                        color: root.language === langChip.modelData ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.language = langChip.modelData
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 44
            color: Appearance.colors.colLayer1
            radius: 15
            StyledText {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "⌕"
                font.pixelSize: 24
                color: Appearance.colors.colPrimary
            }
            StyledText {
                anchors.left: parent.left
                anchors.leftMargin: 50
                anchors.verticalCenter: parent.verticalCenter
                visible: searchField.text === ""
                text: root.t("Buscar atalho, tecla ou comando...", "Search shortcut, key or command...")
                color: Appearance.colors.colSubtext
            }
            TextInput {
                id: searchField
                anchors.left: parent.left
                anchors.leftMargin: 50
                anchors.right: parent.right
                anchors.rightMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                color: Appearance.colors.colOnLayer1
                font.pixelSize: 15
                selectByMouse: true
                clip: true
                onTextChanged: root.query = text
            }
        }

        Flickable {
            id: chipStrip
            Layout.fillWidth: true
            implicitHeight: 39
            contentWidth: chipRow.implicitWidth
            contentHeight: height
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            Row {
                id: chipRow
                spacing: 7
                Repeater {
                    model: root.categories
                    delegate: Rectangle {
                        id: catChip
                        required property var modelData
                        height: 34
                        width: catText.implicitWidth + 24
                        radius: 17
                        color: root.category === modelData.id ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer1
                        border.color: root.category === modelData.id ? Appearance.colors.colPrimary : "transparent"
                        border.width: 1
                        StyledText {
                            id: catText
                            anchors.centerIn: parent
                            text: root.language === "pt" ? catChip.modelData.pt : catChip.modelData.en
                            font.pixelSize: 12
                            font.weight: root.category === catChip.modelData.id ? Font.DemiBold : Font.Normal
                            color: Appearance.colors.colOnLayer1
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.category = catChip.modelData.id
                        }
                    }
                }
            }
        }

        Flickable {
            id: resultsScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: cards.implicitHeight
            boundsBehavior: Flickable.DragOverBounds
            ColumnLayout {
                id: cards
                width: resultsScroll.width
                spacing: 7
                Repeater {
                    model: root.filteredBinds
                    delegate: Rectangle {
                        id: shortcutCard
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 59
                        radius: 16
                        color: shortcutCard.index % 2 === 0 ? Appearance.colors.colLayer1 : Appearance.colors.colLayer1Hover
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 15
                            anchors.rightMargin: 15
                            spacing: 16
                            Rectangle {
                                Layout.preferredWidth: 215
                                Layout.preferredHeight: 35
                                radius: 11
                                color: Qt.rgba(0.48, 0.27, 0.17, 0.24)
                                border.width: 1
                                border.color: Qt.rgba(0.86, 0.65, 0.39, 0.6)
                                StyledText {
                                    anchors.centerIn: parent
                                    text: shortcutCard.modelData.combo
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnLayer1
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                StyledText {
                                    Layout.fillWidth: true
                                    text: shortcutCard.modelData[root.language] || root.translatedDescription(shortcutCard.modelData.description)
                                    font.pixelSize: 14
                                    elide: Text.ElideRight
                                    color: Appearance.colors.colOnLayer1
                                }
                                StyledText {
                                    text: root.categoryName(shortcutCard.modelData.category)
                                    font.pixelSize: 11
                                    color: Appearance.colors.colSubtext
                                }
                            }
                        }
                    }
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.filteredBinds.length === 0
                    text: root.t("Nenhum atalho encontrado", "No shortcuts found")
                    color: Appearance.colors.colSubtext
                }
            }
        }
        StyledText {
            Layout.fillWidth: true
            text: root.t("Lista lida do keybinds.lua; atalhos sem descrição podem não aparecer. Alguns atalhos pessoais estão incluídos.", "Read from keybinds.lua; undescribed shortcuts may not appear. Some personal shortcuts are included.")
            color: Appearance.colors.colSubtext
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }
}
