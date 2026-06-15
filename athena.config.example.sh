#!/usr/bin/env bash
# Личная конфигурация Athena OS. Скопируй → athena.config.sh (gitignored) и заполни.
# Никаких СЕКРЕТОВ здесь — только URL'ы репо и пути. Значения ключей — в Keychain.

# Приватный chezmoi-source с твоими дотфайлами (~/.claude и т.д.).
# Пусто = использовать локальный ./chezmoi из этого репо (generic-канон).
export ATHENA_DOTFILES_REPO=""

# Приватный репо vault Знаний (контент ~/Полезные знания).
export ATHENA_VAULT_REPO=""

# Манифест проектов.
export ATHENA_PROJECTS_MANIFEST="$HOME/Проекты/athena-os/projects.manifest"
