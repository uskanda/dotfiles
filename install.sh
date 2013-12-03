# [nodebrew]{https://github.com/hokaccha/nodebrew}
# ---------------
# Node.js version Manager
if [[ ! -f ~/.nodebrew/nodebrew ]]; then
    echo Install NodeBrew...
    curl -L git.io/nodebrew | perl - setup
    echo done.
fi
