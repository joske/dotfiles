#!/usr/bin/env bash

set -eu

# base
sudo sed -i '/^#Color/s/#Color/Color/' /etc/pacman.conf
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm fish fisher wezterm git base-devel ripgrep rustup lazygit tmux neovim ruby yarn npm btop \
	ranger gdu cpio zip unzip tar gzip bzip2 xz curl wget bc jq tree fzf sccache net-tools man-db less imagemagick exfat-utils \
	lnav docker docker-compose tree-sitter-cli wl-clipboard xclip xsel
sudo pacman -S --needed --noconfirm firefox

# rust
pgrep sccache || sccache --start-server
rustup install nightly
rustup default stable
if [ -d "$HOME/.cargo" ]; then
	cat >"$HOME/.cargo/config.toml" <<EOF
[build]
  rustc-wrapper = "/usr/bin/sccache"
EOF
fi

# AUR
if ! command -v yay >/dev/null; then
	mkdir -p "$HOME/Projects"
	pushd "$HOME/Projects" || true
	rm -rf yay-bin
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
	mkdir -p "$HOME/Pictures/"
	popd || true
fi
rcup -f -x excl -d "$HOME/Projects/dotfiles"

cp "$HOME/Projects/dotfiles/excl/catbackground.jpg" "$HOME/Pictures/"

# gnome
if [ -x /usr/bin/gsettings ] && [ -f "$HOME/Pictures/catbackground.jpg" ]; then
	gsettings set org.gnome.desktop.background picture-uri "file://$HOME/Pictures/catbackground.jpg" || true
	gsettings set org.gnome.desktop.background picture-uri-dark "file://$HOME/Pictures/catbackground.jpg" || true
fi
if [ -x /usr/bin/gnome-shell ]; then
	sudo pacman -S --needed --noconfirm extension-manager dconf-editor
	dconf write /org/gnome/desktop/interface/accent-color "'blue'"
	dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
	dconf write /org/gnome/desktop/interface/enable-hot-corners false
	dconf write /org/gnome/desktop/interface/default-folder-viewer "'list-view'"
	dconf write /org/gnome/desktop/interface/clock-format "'24h'"
	dconf write /org/gnome/desktop/interface/clock-show-date true
	dconf write /org/gnome/desktop/interface/clock-show-seconds true
	dconf write /org/gnome/desktop/interface/clock-show-weekday true
	dconf write /org/gnome/desktop/interface/overlay-scrolling false
	dconf write /org/gnome/desktop/interface/show-battery-percentage true
	dconf write /org/gnome/desktop/wm/preferences/button-layout "'close,minimize,maximize:'"
	dconf write /org/gnome/desktop/wm/preferences/focus-mode "'sloppy'"
	dconf write /org/gnome/desktop/wm/preferences/auto-raise true
	dconf write /org/gnome/desktop/peripherals/touchpad/natural-scroll false
	EXTENSIONS=('dash-to-dock@micxgx.gmail.com' 'logomenu@aryan_k' 'apps-menu@gnome-shell-extensions.gcampax.github.com' 'caffeine@patapon.info'
		'Vitals@CoreCoding.com' 'clipboard-indicator@tudmotu.com' 'places-menu@gnome-shell-extensions.gcampax.github.com' 'top-bar-organizer@julian.gse.jsts.xyz')
	shell_version=$(gnome-shell --version | cut -d' ' -f3)
	function install_extension() {
		uuid=$1
		if [ ! -d "$HOME/.local/share/gnome-shell/extensions/$uuid" ]; then
			info_json=$(curl -sS "https://extensions.gnome.org/extension-info/?uuid=$uuid&shell_version=$shell_version")

			download_url=$(echo "$info_json" | jq ".download_url" --raw-output)

			gnome-extensions install "https://extensions.gnome.org$download_url"
		fi
	}
	for f in "${EXTENSIONS[@]}"; do
		install_extension "$f"
	done

	dconf write /org/gnome/shell/extensions/Logo-menu/show-power-options true
	dconf write /org/gnome/shell/extensions/Logo-menu/show-lockscreen true
	dconf write /org/gnome/shell/extensions/Logo-menu/show-activities-button false
	dconf write /org/gnome/shell/extensions/Logo-menu/menu-button-icon-image 5
	dconf write /org/gnome/shell/extensions/Logo-menu/menu-button-terminal "'wezterm'"
	dconf write /org/gnome/shell/extensions/Logo-menu/menu-button-extensions-app "'com.mattjakeman.ExtensionManager.desktop'"
	dconf write /org/gnome/shell/extensions/dash-to-dock/dash-max-icon-size 32
	dconf write /org/gnome/shell/extensions/dash-to-dock/dock-position "'BOTTOM'"
	dconf write /org/gnome/shell/extensions/dash-to-dock/disable-overview-on-startup true
	dconf write /org/gnome/shell/extensions/top-bar-organizer/center-box-order "['vitalsMenu']"
	dconf write /org/gnome/shell/extensions/top-bar-organizer/right-box-order "['workspace-indicator', 'drive-menu', 'clipboardIndicator', 'screenRecording', 'screenSharing', 'dwellClick', 'keyboard', 'quickSettings', 'dateMenu']"
	dconf write /org/gnome/shell/extensions/vitals/hot-sensors "['__network-rx_max__', '__network-tx_max__', '_storage_read_rate_', '_storage_write_rate_', '_storage_free_']"
fi

# fish
fish -c "alias -s lg lazygit"
fish -c "alias -s vim nvim"
fish -c "fish_add_path $HOME/.local/bin" || true # idempotent
if [ ! -d "$HOME/.config/fish/functions/tide/" ]; then
	fish -c 'fisher install IlanCosman/tide@v6'
	fish -c "tide configure --auto --style=Rainbow --prompt_colors='True color' --show_time='24-hour format' --rainbow_prompt_separators=Angled --powerline_prompt_heads=Sharp --powerline_prompt_tails=Flat --powerline_prompt_style='One line' --prompt_spacing=Compact --icons='Many icons' --transient=No"
	echo "change default login shell to fish: you'll need to enter your PW"
fi
[ "$(getent passwd "$USER" | cut -d: -f7)" = "/usr/bin/fish" ] || chsh -s /usr/bin/fish

# nvim
if [ ! -d "$HOME/.config/nvim" ]; then
	git clone https://github.com/joske/nvim-native "$HOME/.config/nvim"
	nvim --headless +qa
fi

# sysctl
if [ ! -f /etc/sysctl.d/99-sysrq.conf ]; then
	sudo tee /etc/sysctl.d/99-sysrq.conf <<EOF
kernel.sysrq = 1
EOF
	sudo sysctl --system
fi

# yserver
sudo pacman -S --needed --noconfirm xorg-mkfontscale xorg-fonts-misc xterm wmctrl xdotool just gcc libxshmfence libxkbcommon libinput shaderc systemd-libs fontconfig pkgconf mesa scdoc
