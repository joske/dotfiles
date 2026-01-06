#!/bin/sh
exec yay -Slq | sort | uniq | fzf --multi --preview 'yay -Si {1}' | xargs -ro yay -S
