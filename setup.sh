#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"
BACKUP_DIR="$HOME/.dotfiles-backup"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

# ============================================
# 1. Detect OS
# ============================================
detect_os() {
    case "$(uname -s)" in
        Darwin) OS="macos" ;;
        Linux)  OS="linux" ;;
        *)      error "Unsupported OS: $(uname -s)"; exit 1 ;;
    esac
    info "Detected OS: $OS"

    if [ "$OS" = "linux" ]; then
        if command -v apt-get &>/dev/null; then
            PKG_MANAGER="apt"
        elif command -v dnf &>/dev/null; then
            PKG_MANAGER="dnf"
        else
            error "No supported package manager found (apt or dnf)"
            exit 1
        fi
        info "Package manager: $PKG_MANAGER"
    fi
}

# ============================================
# 2. Install packages
# ============================================
install_packages() {
    info "Installing packages..."

    if [ "$OS" = "macos" ]; then
        if ! command -v brew &>/dev/null; then
            info "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew install zsh tmux neovim autojump git curl
    else
        if [ "$PKG_MANAGER" = "apt" ]; then
            sudo apt-get update
            sudo apt-get install -y zsh tmux neovim autojump git curl
        elif [ "$PKG_MANAGER" = "dnf" ]; then
            sudo dnf install -y zsh tmux neovim autojump git curl
        fi
    fi

    success "Packages installed"
}

# ============================================
# 3. Install oh-my-zsh
# ============================================
install_ohmyzsh() {
    if [ -d "$HOME/.oh-my-zsh" ]; then
        success "oh-my-zsh already installed"
        return
    fi

    info "Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    success "oh-my-zsh installed"
}

# ============================================
# 4. Install zsh-autosuggestions plugin
# ============================================
install_zsh_autosuggestions() {
    local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"

    if [ -d "$plugin_dir" ]; then
        success "zsh-autosuggestions already installed"
        return
    fi

    info "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir"
    success "zsh-autosuggestions installed"
}

# ============================================
# 5. Install nvm
# ============================================
install_nvm() {
    if [ -d "$HOME/.nvm" ]; then
        success "nvm already installed"
        return
    fi

    info "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    success "nvm installed"
}

# ============================================
# 6. Install TPM (tmux plugin manager)
# ============================================
install_tpm() {
    local tpm_dir="$HOME/.tmux/plugins/tpm"

    if [ -d "$tpm_dir" ]; then
        success "TPM already installed"
        return
    fi

    info "Installing TPM..."
    git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
    success "TPM installed"
}

# ============================================
# 7. Symlink configs
# ============================================
backup_and_link() {
    local src="$1"
    local dest="$2"

    # If destination exists and is not already a symlink to our source
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
            success "Already linked: $dest -> $src"
            return
        fi

        mkdir -p "$BACKUP_DIR"
        local backup_name
        backup_name="$(basename "$dest").$(date +%Y%m%d%H%M%S)"
        warn "Backing up $dest -> $BACKUP_DIR/$backup_name"
        mv "$dest" "$BACKUP_DIR/$backup_name"
    fi

    # Create parent directory if needed
    mkdir -p "$(dirname "$dest")"

    ln -s "$src" "$dest"
    success "Linked: $dest -> $src"
}

symlink_configs() {
    info "Symlinking config files..."

    backup_and_link "$DOTFILES_DIR/.zshrc"     "$HOME/.zshrc"
    backup_and_link "$DOTFILES_DIR/.vimrc"     "$HOME/.vimrc"
    backup_and_link "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"
    backup_and_link "$DOTFILES_DIR/nvim"       "$HOME/.config/nvim"
}

# ============================================
# 8. Change default shell to zsh
# ============================================
set_default_shell() {
    local zsh_path
    zsh_path="$(which zsh)"

    if [ "$SHELL" = "$zsh_path" ]; then
        success "Default shell is already zsh"
        return
    fi

    info "Changing default shell to zsh..."

    # Ensure zsh is in /etc/shells
    if ! grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
        warn "Adding $zsh_path to /etc/shells"
        echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
    fi

    chsh -s "$zsh_path"
    success "Default shell changed to zsh (takes effect on next login)"
}

# ============================================
# 9. Install tmux plugins
# ============================================
install_tmux_plugins() {
    local tpm_install="$HOME/.tmux/plugins/tpm/bin/install_plugins"

    if [ ! -x "$tpm_install" ]; then
        warn "TPM install script not found, skipping tmux plugin install"
        return
    fi

    info "Installing tmux plugins..."
    TMUX_PLUGIN_MANAGER_PATH="$HOME/.tmux/plugins" "$tpm_install"
    success "Tmux plugins installed"
}

# ============================================
# 10. Print summary
# ============================================
print_summary() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Dotfiles setup complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Symlinks:"
    echo "  ~/.zshrc     -> ~/dotfiles/.zshrc"
    echo "  ~/.vimrc     -> ~/dotfiles/.vimrc"
    echo "  ~/.tmux.conf -> ~/dotfiles/.tmux.conf"
    echo "  ~/.config/nvim -> ~/dotfiles/nvim"
    echo ""

    if [ -d "$BACKUP_DIR" ]; then
        echo "Backups saved to: $BACKUP_DIR"
        echo ""
    fi

    echo "Next steps:"
    echo "  1. Open a new terminal to load zsh + oh-my-zsh"
    echo "  2. Run 'tmux' and press prefix + I to finish plugin install"
    echo "  3. Run 'nvim' to let LazyVim bootstrap plugins"
    echo ""
}

# ============================================
# Main
# ============================================
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Dotfiles Setup${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    detect_os
    install_packages
    install_ohmyzsh
    install_zsh_autosuggestions
    install_nvm
    install_tpm
    symlink_configs
    set_default_shell
    install_tmux_plugins
    print_summary
}

main "$@"
