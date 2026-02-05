#!/usr/bin/env bash
set -uo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup"
ERRORS=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; ERRORS=$((ERRORS + 1)); }

usage() {
    echo "Usage: $(basename "$0") [--install]"
    echo ""
    echo "  (default)    Symlink config files only"
    echo "  --install    Full setup: install packages, tools, and symlink configs"
}

# ============================================
# Symlink configs
# ============================================
backup_and_link() {
    local src="$1"
    local dest="$2"

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
# Install functions (only run with --install)
# ============================================
install_homebrew() {
    if command -v brew &>/dev/null; then
        success "Homebrew already installed"
        return
    fi

    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        error "Failed to install Homebrew"; return 1
    }

    if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    success "Homebrew installed"
}

install_system_packages() {
    info "Installing system packages..."

    case "$(uname -s)" in
        Darwin) ;;
        Linux)
            if command -v apt-get &>/dev/null; then
                sudo apt-get update && sudo apt-get install -y zsh git curl build-essential || {
                    error "Failed to install system packages"; return 1
                }
            elif command -v dnf &>/dev/null; then
                sudo dnf install -y zsh git curl gcc make || {
                    error "Failed to install system packages"; return 1
                }
            else
                error "No supported package manager found (apt or dnf)"; return 1
            fi
            ;;
    esac

    success "System packages installed"
}

install_brew_packages() {
    info "Installing brew packages (vim, neovim, tmux, autojump)..."
    brew install vim neovim tmux autojump || {
        error "Failed to install brew packages"; return 1
    }
    success "Brew packages installed"
}

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

set_default_shell() {
    local zsh_path
    zsh_path="$(which zsh)"

    if [ "$SHELL" = "$zsh_path" ]; then
        success "Default shell is already zsh"
        return
    fi

    info "Changing default shell to zsh..."

    if ! grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
        warn "Adding $zsh_path to /etc/shells"
        echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
    fi

    chsh -s "$zsh_path" || {
        error "Failed to change default shell (run 'chsh -s $zsh_path' manually)"; return 1
    }
    success "Default shell changed to zsh (takes effect on next login)"
}

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
# Summary
# ============================================
print_summary() {
    echo ""
    if [ "$ERRORS" -gt 0 ]; then
        echo -e "${YELLOW}========================================${NC}"
        echo -e "${YELLOW}  Setup finished with $ERRORS error(s)${NC}"
        echo -e "${YELLOW}========================================${NC}"
    else
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}  Setup complete!${NC}"
        echo -e "${GREEN}========================================${NC}"
    fi
    echo ""
    echo "Symlinks:"
    for f in "$HOME/.zshrc" "$HOME/.vimrc" "$HOME/.tmux.conf" "$HOME/.config/nvim"; do
        if [ -L "$f" ]; then
            echo "  $f -> $(readlink "$f")"
        else
            echo "  $f (not a symlink)"
        fi
    done
    echo ""

    if [ -d "$BACKUP_DIR" ]; then
        echo "Backups: $BACKUP_DIR"
        echo ""
    fi
}

# ============================================
# Main
# ============================================
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Dotfiles Setup${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    local do_install=false

    for arg in "$@"; do
        case "$arg" in
            --install) do_install=true ;;
            -h|--help) usage; exit 0 ;;
            *) error "Unknown option: $arg"; usage; exit 1 ;;
        esac
    done

    if [ "$do_install" = true ]; then
        install_system_packages      || true
        install_homebrew             || true
        install_brew_packages        || true
        install_ohmyzsh              || true
        install_zsh_autosuggestions  || true
        install_nvm                  || true
        install_tpm                  || true
    fi

    symlink_configs

    if [ "$do_install" = true ]; then
        set_default_shell    || true
        install_tmux_plugins || true
    fi

    print_summary
}

main "$@"
