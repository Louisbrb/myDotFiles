#! /bin/bash
eval "$(ssh-agent -s)"
ssh-add /home/lbn/sshKeys/sshKeyGithub

git pull
cp /home/lbn/.config/nvim/ neovim/
cp /mnt/c/Users/LBN/.config/wezterm/wezterm.lua wezterm/wezterm.lua

git add -A
git commit -m "another autocommit"
git push
