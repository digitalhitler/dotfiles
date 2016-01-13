#!/bin/bash
#####
# Pre-install OS X config


#
### Setting up workflow
#

echo " * * * Running preinstall...";

# Determine current user
MYUSERNAME=`whoami`;
if [ ! $MYUSERNAME ] || [ $MYUSERNAME = "root" ]; then
	echo "Error: cannot detect current username or maybe you are root?";
	echo "You need to start this script in shell by plain user.";
	echo "We are going out.";
	exit 1;
fi;

## XCode
echo " * Installing XCode command line tools"
xcode-select --install;

## Homebrew
echo " * Installing homebrew";
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
echo "   Yeah! Brew are here - now everything will be easier than ever";

## Node.js
echo " * Installing Node.js";
brew install node;

echo "   Testing Node & NPM";
NODEVERSION=`node -v`;
NPMVERSION=`npm -v`;

echo "   We got Node.js $NODEVERSION and NPM $NPMVERSION";


## NPM config
echo " * Configuring NPM";
npm adduser --registry http://digitalhitler.ru:4873/ --scope=@vkcm --always-auth=false

## NPM deps
echo " * Installing NPM this-app-dependencies"
npm install;

############ MOVE TO NODE
#
# ## Git
# echo " * Installing latest git because of OS X bundled with old one";
# git config --global user.name "Sergey Petrenko";
# git config --global push.default simple
#
# ## Fish
# echo " * Installing fish - interactive shell"
# brew install fish
#
# echo "   Applying fish configuration";
# mkdir -pv ~/.config/fish
# cp fish/config.fish ~/.config/fish/config.fish
#
#
#
# echo "   Installing global packages";
# npm i -g webpack gulp express express-generator node-gyp node-pre-gyp yo webpack-dev-server lodash babel babel-loader babel-polyfill bower browserify eslint jscs jscs-jsdoc grunt less sass;
#
### Some core OS X configuration
# sudo systemsetup -f -setremotelogin on
#####
# Install & initial setup oh-my-fish
# curl -L https://github.com/oh-my-fish/oh-my-fish/raw/master/bin/install | fish
# omf install cmorrell


echo " * * * Preinstall completed.";
