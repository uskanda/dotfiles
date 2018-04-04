# install fisherman if fisher command is missing
if not type -q fisher
  echo "fisherman does not exist. install now."
  curl -s -Lo ~/.config/fish/functions/fisher.fish --create-dirs https://git.io/fisher
  fish -c "fisher"
end

set -U fish_prompt_pwd_dir_length 4
source ~/.config/fish/config_local.fish

#不服だがfunctions/completionsはfishermanにくれてやる
