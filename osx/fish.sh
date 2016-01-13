#### 
# Insall & configure fish - the interactive shell
echo " * Installing fish..."
brew install fish
mkdir -pv ~/.config/fish
cp $SCRIPTDIR/fish/config.fish ~/.config/fish/config.fish