set -x NODE_DIR (dirname (which node))
set -x MYSCRIPTS_DIR ~/.scripts
set -x PATH $PATH $NODE_DIR $MYSCRIPTS_DIR

source ~/.config/fish/completions.fish

function gitpush
  git commit -m $argv
  git push
end
