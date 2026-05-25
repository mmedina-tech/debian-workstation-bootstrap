#!/usr/bin/env bash
# SYNOPSIS: Fresh Debian laptop setup for InTech development tools
#
# InTech_Packages.sh
#
# Author: Marcus Medina
# Date: Thu 08 Jul 2021 07:25:59 AM PDT
# Last Update: 2026-05-24
#

set -euo pipefail

SOURCE_FILE="/etc/apt/sources.list.d/intech-trixie.sources"
BRAVE_SOURCE_FILE="/etc/apt/sources.list.d/brave-browser-release.sources"
BRAVE_KEYRING="/usr/share/keyrings/brave-browser-archive-keyring.gpg"
INSTALL_USER="${SUDO_USER:-root}"
INSTALL_HOME="$(getent passwd "$INSTALL_USER" | cut -d ':' -f 6)"
DOTFILES_DIR="$INSTALL_HOME/dotfiles"

WITH_NETWORK_SHARING=0
WITH_DOMAIN_TOOLS=0

BASE_PACKAGES=(
    "ca-certificates"
    "curl"
    "gnupg"
    "fontconfig"
    "apt-transport-https"
    "apt-utils"
    "aptitude"
    "multitail"
    "shellcheck"
    "git-*"
    "meld"
    "vim"
    "tar"
    "gzip"
    "unzip"
)

DEV_PACKAGES=(
    "build-essential"
    "pkg-config"
    "python*"
    "python3-pip"
    "python3-venv"
    "php*"
    "php-cli"
    "php-mysql"
    "lua5.4"
    "liblua5.4-dev"
    "luarocks"
    "nodejs"
    "npm"
    "rustc"
    "cargo"
    "rustfmt"
    "rust-clippy"
    "mysql*"
    "mariadb-*"
    "libmariadb-*"
    "libdbd-mysql-perl"
    "libdb-perl"
    "default-*"
)

WEB_PACKAGES=(
    "apache2*"
    "libapache2-mod-php"
)

DESKTOP_PACKAGES=(
    "brave-browser"
    "thunderbird"
    "geany-*"
    "*screensaver*"
    "*theme*"
    "*cursors*"
    "*-icons*"
)

LSP_APT_PACKAGES=(
    "rust-analyzer"
    "python3-pylsp"
    "python3-pylsp-black"
    "python3-pylsp-isort"
    "python3-pylsp-mypy"
    "clangd"
)

FORMATTER_APT_PACKAGES=(
    "black"
    "isort"
    "shfmt"
    "tidy"
    "clang-format"
)

FONT_PACKAGES=(
    "fonts-firacode"
)

NPM_GLOBAL_PACKAGES=(
    "@openai/codex"
    "pyright"
    "intelephense"
    "vscode-langservers-extracted"
    "bash-language-server"
    "yaml-language-server"
    "sql-language-server"
    "prettier"
    "sql-formatter"
)

NETWORK_SHARING_PACKAGES=(
    "samba*"
    "nfs*"
)

DOMAIN_PACKAGES=(
    "adcli"
)

show_help() {
    cat <<EOF
Usage: sudo ./InTech_Packages.sh [options]

Options:
  --with-network-sharing   Install Samba and NFS packages.
  --with-domain-tools      Install Active Directory/domain join tools.
  --all-optional           Install all optional package groups.
  --help                   Show this help message.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    --with-network-sharing) WITH_NETWORK_SHARING=1 ;;
    --with-domain-tools) WITH_DOMAIN_TOOLS=1 ;;
    --all-optional)
        WITH_NETWORK_SHARING=1
        WITH_DOMAIN_TOOLS=1
        ;;
    --help | -h)
        show_help
        exit 0
        ;;
    *)
        echo "Unknown option: $1" >&2
        show_help >&2
        exit 1
        ;;
    esac
    shift
done

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root"
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

log() {
    echo
    echo "==> $*"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

ensure_dir() {
    local dir="$1"

    if [[ -d "$dir" ]]; then
        echo "Directory exists: $dir"
    else
        echo "Creating directory: $dir"
        mkdir -p "$dir"
    fi
}

write_debian_sources() {
    log "Writing Debian trixie sources"
    cat <<EOF >"$SOURCE_FILE"
# InTech Debian trixie sources
Types: deb deb-src
URIs: https://deb.debian.org/debian/
Suites: trixie
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

# InTech Debian trixie security sources
Types: deb deb-src
URIs: https://security.debian.org/debian-security/
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

# InTech Debian trixie updates sources
Types: deb deb-src
URIs: https://deb.debian.org/debian/
Suites: trixie-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
}

write_brave_sources() {
    log "Writing Brave source"
    install -d -m 0755 /usr/share/keyrings

    if [[ ! -f "$BRAVE_KEYRING" ]]; then
        curl -fsSLo "$BRAVE_KEYRING" \
            https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
    else
        echo "Brave keyring already exists"
    fi

    cat <<EOF >"$BRAVE_SOURCE_FILE"
Types: deb
URIs: https://brave-browser-apt-release.s3.brave.com/
Suites: stable
Components: main
Signed-By: $BRAVE_KEYRING
EOF
}

install_package_group() {
    local label="$1"
    shift

    log "Installing $label"
    apt install -y "$@"
}

install_neovim() {
    local nvim_archive="/tmp/nvim-linux-x86_64.tar.gz"
    local nvim_url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"

    if command_exists nvim; then
        echo "Neovim already installed: $(command -v nvim)"
        nvim --version | head -n 1
        return
    fi

    log "Installing latest Neovim release"
    curl -fL "$nvim_url" -o "$nvim_archive"
    rm -rf /opt/nvim-linux-x86_64
    tar -C /opt -xzf "$nvim_archive"
    ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
    rm -f "$nvim_archive"
}

install_lua_language_server() {
    local install_dir="/opt/lua-language-server"
    local archive="/tmp/lua-language-server.tar.gz"
    local release_url

    if command_exists lua-language-server; then
        echo "Lua language server already installed: $(command -v lua-language-server)"
        return
    fi

    log "Installing Lua language server"
    release_url="$(curl -fsSL https://api.github.com/repos/LuaLS/lua-language-server/releases/latest |
        grep browser_download_url |
        grep 'linux-x64.tar.gz' |
        cut -d '"' -f 4 |
        head -n 1 ||
        true)"

    if [[ -z "$release_url" ]]; then
        echo "Unable to find Lua language server release URL" >&2
        return 1
    fi

    rm -rf "$install_dir"
    ensure_dir "$install_dir"
    curl -fL "$release_url" -o "$archive"
    tar -C "$install_dir" -xzf "$archive"
    ln -sf "$install_dir/bin/lua-language-server" /usr/local/bin/lua-language-server
    rm -f "$archive"
}

install_npm_tools() {
    if ! command_exists npm; then
        install_package_group "Node.js and npm" "nodejs" "npm"
    fi

    log "Installing Codex, npm language servers, and npm formatters"
    npm install -g "${NPM_GLOBAL_PACKAGES[@]}"
}

install_php_cs_fixer() {
    local target="/usr/local/bin/php-cs-fixer"
    local download_url="https://cs.symfony.com/download/php-cs-fixer-v3.phar"

    if command_exists php-cs-fixer; then
        echo "PHP-CS-Fixer already installed: $(command -v php-cs-fixer)"
        return
    fi

    log "Installing PHP-CS-Fixer"
    curl -fsSL "$download_url" -o "$target"
    chmod 0755 "$target"
}

install_stylua() {
    local cargo_home="/usr/local/cargo"
    local cargo_bin="$cargo_home/bin"

    if command_exists stylua; then
        echo "StyLua already installed: $(command -v stylua)"
        return
    fi

    if ! command_exists cargo; then
        install_package_group "Rust cargo" "cargo"
    fi

    log "Installing StyLua"
    ensure_dir "$cargo_home"
    ensure_dir "$cargo_bin"
    CARGO_HOME="$cargo_home" PATH="$cargo_bin:$PATH" cargo install stylua --locked
    ln -sf "$cargo_bin/stylua" /usr/local/bin/stylua
}

install_firacode_nerd_font() {
    local font_dir="/usr/local/share/fonts/FiraCodeNerdFont"
    local archive="/tmp/FiraCodeNerdFont.zip"
    local font_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"

    if command_exists fc-list && fc-list | grep -qi "FiraCode Nerd Font"; then
        echo "FiraCode Nerd Font already installed"
        return
    fi

    log "Installing FiraCode Nerd Font"
    ensure_dir "$font_dir"
    curl -fL "$font_url" -o "$archive"
    unzip -o -q "$archive" -d "$font_dir"
    find "$font_dir" -type f \( -name "*.ttf" -o -name "*.otf" \) -exec chmod 0644 {} +
    fc-cache -f "$font_dir"
    rm -f "$archive"
}

configure_web_dirs() {
    log "Configuring Apache web directories"
    ensure_dir "/var/www"
    ensure_dir "/var/www/html"
    ensure_dir "/var/www/cgi-bin"

    if getent group www-data >/dev/null 2>&1; then
        chown -R "$INSTALL_USER:www-data" /var/www
    fi

    find /var/www -type d -exec chmod 775 {} +
}

configure_apache() {
    log "Enabling Apache CGI"
    a2enmod cgi

    if systemctl restart apache2; then
        echo "Apache restart successful"
    else
        echo "Apache restart failed" >&2
        return 1
    fi
}

prepare_dotfiles_stub() {
    log "Preparing dotfiles stub"

    if [[ "$INSTALL_USER" == "root" || -z "$INSTALL_HOME" ]]; then
        echo "Skipping user dotfiles stub because no sudo user was detected"
        return
    fi

    ensure_dir "$DOTFILES_DIR"
    ensure_dir "$INSTALL_HOME/.config"
    ensure_dir "$INSTALL_HOME/.config/nvim"
    ensure_dir "$INSTALL_HOME/.config/wezterm"
    ensure_dir "$INSTALL_HOME/.config/kitty"
    ensure_dir "$INSTALL_HOME/.local/bin"
    ensure_dir "$INSTALL_HOME/bin"

    cat <<EOF >"$DOTFILES_DIR/README.md"
# Marcus Medina Dotfiles

This is a placeholder for the dotfiles repo that will restore shell, editor,
terminal, Git, and Codex configuration after a fresh Debian install.

Planned config targets:
- ~/.bashrc
- ~/.aliases
- ~/.gitconfig
- ~/.config/nvim
- ~/.config/wezterm
- ~/.config/kitty
- ~/.config/starship.toml
- ~/.codex
EOF

    chown -R "$INSTALL_USER:$INSTALL_USER" "$DOTFILES_DIR" \
        "$INSTALL_HOME/.config" "$INSTALL_HOME/.local" "$INSTALL_HOME/bin"
    echo "Dotfiles stub ready: $DOTFILES_DIR"
}

write_debian_sources
apt update

install_package_group "base tools" "${BASE_PACKAGES[@]}"
write_brave_sources
apt update

install_package_group "development languages and databases" "${DEV_PACKAGES[@]}"
install_package_group "web server packages" "${WEB_PACKAGES[@]}"
install_package_group "desktop packages" "${DESKTOP_PACKAGES[@]}"
install_package_group "apt language servers" "${LSP_APT_PACKAGES[@]}"
install_package_group "apt formatters" "${FORMATTER_APT_PACKAGES[@]}"
install_package_group "font packages" "${FONT_PACKAGES[@]}"

if [[ $WITH_NETWORK_SHARING -eq 1 ]]; then
    install_package_group "network sharing packages" "${NETWORK_SHARING_PACKAGES[@]}"
else
    log "Skipping Samba/NFS packages"
fi

if [[ $WITH_DOMAIN_TOOLS -eq 1 ]]; then
    install_package_group "domain join packages" "${DOMAIN_PACKAGES[@]}"
else
    log "Skipping domain join packages"
fi

install_neovim
install_lua_language_server
install_npm_tools
install_php_cs_fixer
install_stylua
install_firacode_nerd_font
prepare_dotfiles_stub
configure_web_dirs
configure_apache

log "Manual follow-up"
echo "Read Chapter 65 in MySQL Notes for Professionals to reset the root password for mysql."
echo "Review /etc/apache2/conf-available/serve-cgi-bin.conf if your CGI path needs customization."
echo "Populate $DOTFILES_DIR and push it to GitHub when the dotfiles pass is ready."
echo "Formatters installed: black, isort, shfmt, tidy, clang-format, rustfmt, prettier, sql-formatter, php-cs-fixer, stylua."
echo "Font installed: FiraCode Nerd Font."
echo "Run with --with-network-sharing or --with-domain-tools if this laptop needs those optional services."
