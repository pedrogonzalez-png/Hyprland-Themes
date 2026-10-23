# Instalação das personalizações do Hyprland-Themes (prévia)

Este instalador **não substitui a instalação oficial do Arch, Hyprland ou end-4**. Ele configura o desktop sobre o [illogical-impulse](https://github.com/end-4/dots-hyprland) existente e a versão exata do [pctrade/end4-pC](https://github.com/pctrade/end4-pC) usada para construir nosso patch.

## Pré-requisitos e limitações

- Arch com end-4/illogical-impulse instalado seguindo [o guia original](https://ii.clsty.link/).
- Git, Bash, Python 3; `ripgrep (rg)` é recomendado para a triagem de caminhos privados.
- Espaço para o backup integral de `~/.config/quickshell/end4-pC` e das configurações substituídas.
- Os programas referenciados no Hyprland, como Rofi, Kitty, Fish, Fastfetch, btop e tty-clock, precisam existir. **O instalador não instala pacotes.**
- O script **não prepara um ambiente 100% plug-and-play**: os caminhos de wallpaper e recursos visuais ainda dependem dos arquivos escolhidos por cada usuário.

Teste primeiro em uma VM/usuário de teste; não use `--apply` no seu desktop personalizado atual. O Controller Mode privado não faz parte do pacote.

## 1. Obter o código

```fish
git clone https://github.com/pedrogonzalez-png/Hyprland-Themes.git
cd Hyprland-Themes
```

Após instalar a base illogical-impulse, se o diretório `~/.config/quickshell/end4-pC` **ainda não existir**:

```fish
bash install-desktop.sh --prepare-base
```

Esse comando baixa o repositório oficial pctrade/end4-pC e seleciona, em estado *detached HEAD*, o commit `8fbb6716cba628a13103e665e9538021683a7250`. Se o diretório já existir, **recusa substituir ou apagar seus arquivos**. Caso seu end4-pC esteja em versão diferente ou tenha alterações, mantenha-o intacto e use outro usuário/VM para os testes.

## 2. Verificar sem instalar

```fish
bash install-desktop.sh --check
```

Confere os arquivos públicos, clona localmente o checkout end4-pC para uma pasta temporária, posiciona-o no commit correto e testa a aplicação do patch e os quatro arquivos novos. **Não modifica** o Hyprland nem o Quickshell ativos. Esperado: `READ-ONLY CHECK PASSED`.

O `--check` confirma a compatibilidade do patch, **não** todos os requisitos de runtime (QML, Quickshell, temas, dependências ou aparência).

## 3. Aplicar somente no ambiente de teste

```fish
bash install-desktop.sh --apply
```

O script exige um checkout end4-pC limpo, sem arquivos extras e exatamente no commit pinado. É necessário digitar `APLICAR`. Ele faz backup do checkout e dos arquivos preexistentes, aplica as mudanças, copia os dotfiles públicos e instala os dez JSONs de temas.

Os backups ficam em `~/.local/share/Hyprland-Themes/backups/<data-id>/`. Se um comando normal falhar durante a cópia, o instalador **tenta reverter** as configurações copiadas, remover arquivos criados e restaurar o checkout original. Isso não é garantia contra desligamento inesperado, falta de espaço ou `kill -9`: nesses casos, use os backups para recuperação manual. Ele **não recarrega** Hyprland/Quickshell e não ativa serviços automaticamente.

## 4. Tema por wallpaper — ativação opcional

Selecione um wallpaper e tema pelo end4-pC. Para criar uma associação explícita e habilitar o monitoramento:

```fish
~/.local/bin/end4-wallpaper-theme status
~/.local/bin/end4-wallpaper-theme bind changli
systemctl --user enable --now end4-wallpaper-theme.path
```

Outras opções: `bind hiyuki`, `bind emilia`, `bind furina`, `bind hotline-miami`. O script também tenta reconhecer o tema pelo nome do wallpaper. Para desativar o serviço:

```fish
systemctl --user disable --now end4-wallpaper-theme.path
```

Se não disparar, confira `systemctl --user status end4-wallpaper-theme.path` e `journalctl --user -u end4-wallpaper-theme.service -n 30`. O arquivo de associações de wallpapers é criado sob `~/.config/illogical-impulse/`, não é publicado.

## 5. Fastfetch / imagem personalizada

O preset padrão usa logo automático do sistema porque `Changli.webp` não é distribuído. Se você possui uma imagem que pode usar, veja a seção **Fastfetch image** no README para habilitar `kitty-icat` manualmente.

## Recuperação e segurança

- Com erro durante `--apply`, veja o caminho `Recovery attempted; inspect backup: ...` e confirme manualmente o estado dos arquivos.
- Depois de uma instalação concluída, não há botão de rollback automático. Os originais ficam em `backups/<data-id>/originals/` e a cópia anterior do Quickshell em `backups/<data-id>/quickshell/end4-pC/`.
- Não sobrescreva uma configuração personalizada posterior com backups antigos sem comparar os arquivos.
- Nenhum wallpaper, imagem protegida, script do Controller Mode ou token pessoal deve ser colocado nesse repositório.

O instalador foi exercitado com fixtures locais (verificação, cancelamento, falha simulada e reversão). **Ainda precisa de teste visual completo em uma instalação Arch limpa.**
