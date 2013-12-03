# [nodebrew]{https://github.com/hokaccha/nodebrew}
# ---------------
# Node.js version Manager
if [[ ! -f ~/.nodebrew/nodebrew ]]; then
    echo Install NodeBrew...
    curl -L git.io/nodebrew | perl - setup
    echo done.
else
    echo NodeBrew exists. Skip install.
fi

# Bundler
# RubyGems Manager
if which bundle > /dev/null; then
    echo Bundler exists. Skip install.
else
    gem install bundler
fi
