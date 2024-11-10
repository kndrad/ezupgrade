#!/bin/sh

read -p "Use pacman or yay? (pac/yay): " choice

if [ "$choice" = "pac" ]; then
    sudo pacman-key --refresh-keys
    if ! sudo pacman -Syu --noconfirm; then
        echo "Error: System upgrade failed"
        exit 1
    fi
    sudo paccache -r
else
    yay -Syu --noconfirm
    yay -Scc --noconfirm
fi

sudo pacman -Qtdq
sudo pacman -Rns $(pacman -Qtdq)
sudo pacman -Sc --noconfirm
sudo pacman -Rns $(pacman -Qtdq) --noconfirm

sudo journalctl --vacuum-time=2weeks || log_error "Failed to vacuum journalctl"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

if command_exists npm; then
    NODE_NO_WARNING=1 npm cache clean --force || log_error "Failed to clean npm cache"
fi

if command_exists npm; then
    yarn cache clean || log_error "Failed to clean yarn cache"
fi

rm -rf ~/.cache/thumbnails/*

rm -f ~/.local/share/recently-used.xbel
rm -f ~/.recently-used
rm -rf ~/.local/share/Trash/* 2>/dev/null
sudo rm -rf /tmp/* 2>/dev/null

# broken symlinks cleanup
find ~ -xtype l -delete 2>/dev/null
