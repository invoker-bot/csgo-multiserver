
Core.Sourcemod.DropsSummoner::install() {
    echo "Target Sourcemod folder: $SM_DIR"
    echo "Copying files..."
    cp -p "$PLUGINS_SOURCE_DIR/DropsSummoner.games.txt" "$SM_DIR/gamedata"
    cp -p "$PLUGINS_SOURCE_DIR/DropsSummoner.sp" "$SM_DIR/scripting"
    local CURRENT_DIR=$(pwd)
    cd "$SM_DIR/scripting"
    ./compile.sh DropsSummoner.sp && mv compiled/DropsSummoner.smx ../plugins

    if [[ -r ../plugins/DropsSummoner.smx ]]; then
        success <<< "Install plugin DropsSummoner successfully"
    fi
    cd $CURRENT_DIR
}