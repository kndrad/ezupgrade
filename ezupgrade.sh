#!/bin/sh

# Redirects to stderr for better visibility in logs and terminals
log_error() {
    echo "ERROR: $1" >&2
}

# More reliable than 'which' as it works consistently across distros
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Prevents errors when no orphans exist by checking first
remove_orphans() {
    orphans=$(pacman -Qtdq 2>/dev/null)
    if [ -n "$orphans" ]; then
        echo "Removing orphaned packages..."
        sudo pacman -Rns $orphans --noconfirm
    else
        echo "No orphaned packages to remove."
    fi
}

# Resolves the file conflicts seen in the failed upgrade
fix_yarn_conflicts() {
    if [ -f "/usr/bin/yarn" ] || [ -f "/usr/bin/yarnpkg" ] || [ -d "/usr/lib/node_modules/yarn" ]; then
        echo "Detected existing yarn files that may conflict with package installation"
        echo "Attempting to remove conflicting yarn files..."
        sudo rm -f /usr/bin/yarn /usr/bin/yarnpkg
        sudo rm -rf /usr/lib/node_modules/yarn
        echo "Yarn conflicts resolved"
    fi
}

read -p "Use pacman or yay? (pac/yay): " choice

if [ "$choice" = "pac" ]; then
    echo "Refreshing package keys..."
    sudo pacman-key --refresh-keys
    echo "Upgrading system using pacman..."
    if ! sudo pacman -Syu --noconfirm; then
        log_error "System upgrade failed"
        exit 1
    fi
    echo "Cleaning pacman cache..."
    sudo paccache -r
else
    # Preemptively fix conflicts before they cause upgrade failures
    echo "Checking for package conflicts before upgrade..."
    fix_yarn_conflicts

    echo "Upgrading system using yay..."
    if ! yay -Syu --noconfirm; then
        # Second chance if the first attempt fails - many AUR conflicts can be resolved
        log_error "System upgrade failed with yay. Attempting to fix yarn conflicts and retry..."
        fix_yarn_conflicts

        if ! yay -Syu --noconfirm; then
            log_error "System upgrade failed again. Please check the errors above."
            exit 1
        fi
    fi

    # Force confirmation to avoid interactive prompts
    echo "Cleaning package cache..."
    yes | yay -Scc

    # Fix the permission denied errors seen in yay cache
    if [ -d "$HOME/.cache/yay" ]; then
        echo "Fixing permissions in yay cache directory..."
        sudo find "$HOME/.cache/yay" -type d -exec chmod 755 {} \; 2>/dev/null
        sudo find "$HOME/.cache/yay" -type f -exec chmod 644 {} \; 2>/dev/null
    fi
fi

echo "Checking for orphaned packages..."
remove_orphans

echo "Cleaning pacman cache..."
sudo pacman -Sc --noconfirm

echo "Vacuuming systemd journal..."
# Keeps logs but prevents them from filling the disk
sudo journalctl --vacuum-time=2weeks || log_error "Failed to vacuum journalctl"

if command_exists npm; then
    echo "Cleaning npm cache..."
    # NODE_NO_WARNING suppresses deprecation warnings
    NODE_NO_WARNING=1 npm cache clean --force || log_error "Failed to clean npm cache"
fi

if command_exists yarn; then
    echo "Cleaning yarn cache..."
    yarn cache clean || log_error "Failed to clean yarn cache"
fi

echo "Cleaning thumbnails cache..."
# Redirect errors to prevent verbose output on missing files
rm -rf ~/.cache/thumbnails/* 2>/dev/null

echo "Cleaning recent files and trash..."
rm -f ~/.local/share/recently-used.xbel 2>/dev/null
rm -f ~/.recently-used 2>/dev/null
rm -rf ~/.local/share/Trash/* 2>/dev/null

echo "Cleaning temporary files..."
sudo rm -rf /tmp/* 2>/dev/null

echo "Cleaning broken symlinks in home directory..."
# xtype l specifically targets broken symbolic links only
find ~ -xtype l -delete 2>/dev/null

echo "System cleanup completed successfully!"
