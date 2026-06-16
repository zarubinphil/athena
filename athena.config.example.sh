#!/usr/bin/env bash
# Личная конфигурация Athena. Скопируй → athena.config.sh (gitignored) и заполни.
# Никаких СЕКРЕТОВ здесь — только URL'ы репо и пути. Значения ключей — в Keychain.

# ПРОДВИНУТОЕ: готовый внешний chezmoi-source целиком (минует merge generic⊕private).
# Обычно пусто — используется merged-source ниже.
export ATHENA_DOTFILES_REPO=""

# Приватный overlay (athena-private): личные references + launchd + run_once_ секретов.
# Пусто = generic-only. Заданный репо клонится в ATHENA_PRIVATE_DIR и накладывается на generic.
export ATHENA_PRIVATE_REPO=""
export ATHENA_PRIVATE_DIR="$HOME/Проекты/athena-private"

# Приватный репо vault Знаний (контент ~/Мозг).
export ATHENA_VAULT_REPO=""

# Манифест проектов. Если в ATHENA_PRIVATE_DIR есть projects.manifest — он перекроет этот.
export ATHENA_PROJECTS_MANIFEST="$HOME/Проекты/athena/projects.manifest"

# Внешние инструменты → ~/tools (Слой 0b, напр. telegram-бот). По умолчанию берётся
# tools.manifest из приватного overlay (ATHENA_PRIVATE_DIR).
export ATHENA_TOOLS_MANIFEST="$ATHENA_PRIVATE_DIR/tools.manifest"
