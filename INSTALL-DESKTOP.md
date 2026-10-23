# Hyprland-Themes — instalador de personalizações (prévia)

Este pacote acompanha o repositório local `end4-pC-character-themes` e requer que os diretórios `dots/`, `overrides/` e `install.sh` estejam presentes ao lado de `install-desktop.sh`.

**Atenção:** esta versão aplica personalizações sobre o **illogical-impulse + end4-pC previamente instalados**. Ela **não instala o Arch, Hyprland ou todas as dependências do end-4 do zero**. Para a base original, consulte os projetos [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) e [pctrade/end4-pC](https://github.com/pctrade/end4-pC).

## Primeiro teste — sem alterações

No terminal Fish:

```fish
cd ~/Downloads/end4-pC-character-themes
bash install-desktop.sh --check
```

O script clona a base local do end4-pC **em diretório temporário**, seleciona o commit de referência, testa o patch e os 4 arquivos extras; o diretório temporário é apagado ao sair. Não modifica arquivos em `~/.config/` ou `~/.local/`.

## Instalação experimental, somente em sistema de teste

```fish
bash install-desktop.sh --apply
```

O script exige que o repositório end4-pC em `~/.config/quickshell/end4-pC` esteja exatamente na versão indicada pelo arquivo `overrides/end4-pC-base-commit.txt` **e sem alterações locais**. No seu Arch personalizado ele provavelmente **se recusará a instalar de propósito**; isso protege o trabalho em andamento. Use um ambiente Arch de teste já configurado com a base original.

Quando permitido, faz backup da instalação end4-pC e dos arquivos de configuração que substituir. Nunca usa sudo, não habilita serviços, não reinicia Quickshell/Hyprland, nem instala o Controller Mode privado. Não contém wallpapers de terceiros nem a imagem da Changli para Fastfetch.

**Em caso de falha, não reinicie o Hyprland antes de revisar os arquivos e o backup.** Backups são salvos em `~/.local/share/Hyprland-Themes/backups/`.

## Antes de publicar

Revise os caminhos, scripts e dependências copiados em `dots/` e `overrides/`. A triagem automatizada de termos sensíveis não substitui revisão humana. O `--check` é um teste de aplicação de patch, **não um teste visual/funcional de toda a sessão**.
