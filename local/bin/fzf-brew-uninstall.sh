#!/bin/sh
exec brew list | sort | fzf --multi --preview 'brew info {1}' | xargs brew uninstal
