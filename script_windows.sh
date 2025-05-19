#! /bin/bash
eval "$(ssh-agent -s)"
ssh-add /home/lbn/sshKeys/sshKeyGithub

git pull
cp -r /home/lbn/.config/nvim/ neovim/
cp -r /mnt/c/Users/LBN/.config/wezterm/ wezterm/

git add -A
git commit -m "another autocommit"
git push
