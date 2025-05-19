#! /bin/bash
eval "$(ssh-agent -s)"
ssh-add /home/lbn/sshKeys/sshKeyGithub

git pull

cp /mnt/c/Users/LBN/.config/wezterm/wezterm.lua repos/personal/myDotFiles/wezterm/wezterm.lua

git add -A
git commit -m "another autocommit"
git push
