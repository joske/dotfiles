#!/usr/bin/env bash

set -eu

# base
sudo pacman -S --needed --noconfirm fish fisher wezterm git base-devel ripgrep rustup lazygit tmux neovim ruby yarn npm btop ranger gdu cpio zip unzip tar gzip bzip2 xz curl wget bc jq tree fzf sccache net-tools man-db less imagemagick exfat-utils lnav docker docker-compose tree-sitter-cli
sudo pacman -S --needed --noconfirm firefox

# gnome
if [ -x /usr/bin/gsettings ] && [ -f "$HOME/Pictures/catbackground.jpg" ]; then
	gsettings set org.gnome.desktop.background picture-uri "file://$HOME/Pictures/catbackground.jpg" || true
fi
if [ -x /usr/bin/gnome-session ]; then
	sudo pacman -S --needed --noconfirm extension-manager dconf-editor
	dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
	dconf write /org/gnome/desktop/peripherals/touchpad/natural-scroll false
	dconf write /org/gnome/desktop/wm/preferences/focus-mode "'sloppy'"
	dconf write /org/gnome/desktop/wm/preferences/auto-raise true
	dconf write /org/gnome/desktop/interface/show-battery-percentage true
	dconf write /org/gnome/nautilus/preferences/default-folder-viewer "'list-view'"
fi

# rust
rustup install nightly
rustup default stable
cat >"$HOME/.cargo/config.toml" <<EOF
[build]
  rustc-wrapper = "/usr/bin/sccache"
EOF
sccache --start-server || true # fails if already running - cheap way to make idempotent

# AUR
if [ ! -d "$HOME/Projects/yay-bin" ]; then
	mkdir "$HOME/Projects"
	pushd "$HOME/Projects" || true
	git clone https://aur.archlinux.org/yay-bin.git || exit
	pushd yay-bin || true
	makepkg -siA --noconfirm
	popd || true
	popd || true
fi

yay -S --needed --noconfirm rcm mergers ttf-ubuntu-mono-nerd

# dotfiles
if [ ! -d "$HOME/Projects/dotfiles" ]; then
	pushd "$HOME/Projects/" || true
	git clone https://github.com/joske/dotfiles
	popd || true
fi
rcup -d "$HOME/Projects/dotfiles"

# fish
fish -c "alias -s lg lazygit"
fish -c "alias -s vim nvim"
fish -c "fish_add_path $HOME/.local/bin" || true # idempotent
if [ ! -d "$HOME/.config/fish/functions/tide/" ]; then
	fish -c 'fisher install IlanCosman/tide@v6'
	fish -c "tide configure --auto --style=Rainbow --prompt_colors='True color' --show_time='24-hour format' --rainbow_prompt_separators=Angled --powerline_prompt_heads=Sharp --powerline_prompt_tails=Flat --powerline_prompt_style='One line' --prompt_spacing=Compact --icons='Many icons' --transient=No"
fi

# nvim
if [ ! -d "$HOME/.config/nvim" ]; then
	git clone https://github.com/joske/nvim-native "$HOME/.config/nvim"
	nvim --headless +qa
fi

# sysctl
if [ ! -d /etc/sysctl.d/99-sysrq.conf ]; then
	sudo tee /etc/sysctl.d/99-sysrq.conf <<EOF
kernel.sysrq = 1
EOF
	sudo sysctl --system
fi

# yserver
sudo pacman -S --needed --noconfirm xorg-mkfontscale xorg-fonts-misc xterm wmctrl xdotool just gcc libxshmfence libxkbcommon libinput shaderc systemd-libs fontconfig pkgconf mesa scdoc
