#!/bin/sh

read -p "Do you want to upgrade using pacman or yay? (pac/yay): " choice

if [ "$choice" = "pac" ]; then
    # upgrade using pacman and clean
    sudo pacman -Syu --noconfirm
    sudo paccache -r
else
    # yay upgrade and clean
    yay -Syu --noconfirm
    yay -Scc --noconfirm
fi

# orphans and dropped packages removal
sudo pacman -Qtdq
sudo pacman -Rns $(pacman -Qtdq)

# remove cached package files
sudo pacman -Sc --noconfirm

# remove unused packages (optional)
sudo pacman -Rns $(pacman -Qtdq) --noconfirm

# remove old configuration files
sudo find /etc -name "*.pacsave" -delete
sudo find /etc -name "*.pacnew" -delete

# clean journal logs (optional)
sudo journalctl --vacuum-time=2weeks

# clean yarn cache
yarn cache clean

# clean npm cache
npm cache clean --force

# clean pip cache
# uncomment if you have pip installed
#pip cache purge

# clean thumbnails cache
rm -rf ~/.cache/thumbnails/*

# clean recent documents history
rm -f ~/.local/share/recently-used.xbel
rm -f ~/.recently-used

# clean trash and temporary files
rm -rf ~/.local/share/Trash/*
sudo rm -rf /tmp/*

# clean broken symlinks
find ~ -xtype l -delete