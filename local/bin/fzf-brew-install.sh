#!/bin/sh

{
  brew formulae
  brew casks
} | sort | fzf --multi --preview 'brew info {1}' | xargs brew install
