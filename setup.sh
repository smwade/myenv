#!/usr/bin/env bash
set -uo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup"
ERRORS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; ERRORS=$((ERRORS + 1)); }

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
# Helper: Install neovim from GitHub releases (Linux)
# ============================================
install_neovim_linux() {
    local current_ver=""
    if command -v nvim &>/dev/null; then
        current_ver="$(nvim --version | head -1 | grep -oP 'v\K[0-9]+\.[0-9]+\.[0-9]+')"
    fi

    local required_ver="0.11.2"

    # Check if current version is sufficient
    if [ -n "$current_ver" ]; then
        if printf '%s\n%s\n' "$required_ver" "$current_ver" | sort -V | head -1 | grep -qx "$required_ver"; then
            success "Neovim $current_ver already meets minimum ($required_ver)"
            return
        fi
        info "Neovim $current_ver is too old (need >= $required_ver), upgrading..."
    else
        info "Installing Neovim from GitHub releases..."
    fi

    local arch
    arch="$(uname -m)"
    local nvim_tar="nvim-linux-${arch}.tar.gz"
    local nvim_url="https://github.com/neovim/neovim/releases/latest/download/${nvim_tar}"

    curl -fsSL "$nvim_url" -o "/tmp/${nvim_tar}" || {
        error "Failed to download Neovim"; return 1
    }

    sudo rm -rf /opt/nvim
    sudo tar -C /opt -xzf "/tmp/${nvim_tar}" || {
        error "Failed to extract Neovim"; return 1
    }
    rm -f "/tmp/${nvim_tar}"

    # Symlink to /usr/local/bin so it's on PATH
    sudo ln -sf /opt/nvim-linux-${arch}/bin/nvim /usr/local/bin/nvim

    success "Neovim $(nvim --version | head -1) installed to /opt"
}

# ============================================
# 2. Install packages
# ============================================
install_packages() {
    info "Installing packages..."

    if [ "$OS" = "macos" ]; then
        if ! command -v brew &>/dev/null; then
            info "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
                error "Failed to install Homebrew"; return 1
            }
        fi
        brew install zsh tmux neovim autojump git curl || {
            error "Failed to install some packages"; return 1
        }
    else
        if [ "$PKG_MANAGER" = "apt" ]; then
            sudo apt-get update && sudo apt-get install -y zsh tmux autojump git curl || {
                error "Failed to install some packages"; return 1
            }
        elif [ "$PKG_MANAGER" = "dnf" ]; then
            sudo dnf install -y zsh tmux autojump git curl || {
                error "Failed to install some packages"; return 1
            }
        fi
        install_neovim_linux
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
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || {
        error "Failed to install oh-my-zsh"; return 1
    }
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
    git clone https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir" || {
        error "Failed to install zsh-autosuggestions"; return 1
    }
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
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash || {
        error "Failed to install nvm"; return 1
    }
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
    git clone https://github.com/tmux-plugins/tpm "$tpm_dir" || {
        error "Failed to install TPM"; return 1
    }
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

    chsh -s "$zsh_path" || {
        error "Failed to change default shell (you can run 'chsh -s $zsh_path' manually)"; return 1
    }
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
    TMUX_PLUGIN_MANAGER_PATH="$HOME/.tmux/plugins" "$tpm_install" || {
        error "Failed to install tmux plugins"; return 1
    }
    success "Tmux plugins installed"
}

# ============================================
# 10. Print summary
# ============================================
print_summary() {
    echo ""
    if [ "$ERRORS" -gt 0 ]; then
        echo -e "${YELLOW}========================================${NC}"
        echo -e "${YELLOW}  Dotfiles setup finished with $ERRORS error(s)${NC}"
        echo -e "${YELLOW}========================================${NC}"
    else
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}  Dotfiles setup complete!${NC}"
        echo -e "${GREEN}========================================${NC}"
    fi
    echo ""
    echo "Symlinks:"
    ls -la "$HOME/.zshrc" "$HOME/.vimrc" "$HOME/.tmux.conf" "$HOME/.config/nvim" 2>&1 | while read -r line; do
        echo "  $line"
    done
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
    install_packages  || true
    install_ohmyzsh   || true
    install_zsh_autosuggestions || true
    install_nvm       || true
    install_tpm       || true
    symlink_configs
    set_default_shell || true
    install_tmux_plugins || true
    print_summary
}

main "$@"
