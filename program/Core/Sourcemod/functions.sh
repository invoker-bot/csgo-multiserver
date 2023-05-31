#! /bin/bash

# (C) 2023 Invoker Bot <invoker-bot@outlook.com>
#
# This file is licensed under the Apache License 2.0. For more information,
# see the LICENSE file or visit: http://www.apache.org/licenses/LICENSE-2.0

Core.Sourcemod::registerCommands () {
	simpleCommand "Core.Sourcemod::setup" sm:setup
	oneArgCommand "Core.Sourcemod::install" sm:install
    Core.Sourcemod::init
}

Core.Sourcemod::init() {
	SM_HOME="$USER_DIR/$APP/addons/sourcemod-helper"
	SM_CONFIG_DIR="$SM_HOME/configs"
	SM_TMP_DIR="$SM_HOME/tmp"
	SM_TARGET_DIR="$INSTANCE_DIR/$APP"
	SM_DIR="$SM_TARGET_DIR/addons/sourcemod"
	SM_FILECACHE_DIR="$SM_HOME/filecache"
	mkdir -p "$SM_TMP_DIR"
	mkdir -p "$SM_FILECACHE_DIR"
	SM_TMP_DIR="$(mktemp -d -p "$SM_TMP_DIR")"
	SM_TMP_CONFIG_DIR="$SM_TMP_DIR/addons/sourcemod/configs"
	SM_TMP_PLUGIN_DIR="$SM_TMP_DIR/addons/sourcemod/plugins"
	SM_TMP_EXTENSION_DIR="$SM_TMP_DIR/addons/sourcemod/extensions"
}

Core.Sourcemod::downloadFile () {
	[[ $2 ]] || return
	local cachefile="$SM_FILECACHE_DIR/$2"
	[[ -r $cachefile ]] || {
		local tmp=$(mktemp)
		wget -O "$tmp" "$1" || return
		local sha="$(sha256sum "$tmp")"
		sha=${sha%% *}
		[[ $sha == $2 ]] || {
			error <<< "Mismatched checksum for file $1 (expected $2, got $sha)"
			return 1
		}
		mv "$tmp" "$cachefile"
	}
	echo "$cachefile"
}

Core.Sourcemod::unpackZip () {
	local zipfile="$(Core.Sourcemod::downloadFile "$@")"
	[[ -r $zipfile ]] && unzip -q "$zipfile"
}

Core.Sourcemod::unpackTar () {
	local tarfile="$(Core.Sourcemod::downloadFile "$@")"
	[[ -r $tarfile ]] && tar xzf "$tarfile"
}

Core.Sourcemod::downloadSmx () {
	local smxname="${3-${1##*/}}"
	local smxfile="$(SourcemodHelper::downloadFile "$@")"
	[[ -r $smxfile ]] && cp "$smxfile" "$SM_TMP_PLUGIN_DIR/$smxname"
}

Core.Sourcemod::setup() {

	local sourcemodTarFile=$(Core.Sourcemod::downloadFile \
		https://sm.alliedmods.net/smdrop/1.11/sourcemod-1.11.0-git6934-linux.tar.gz \
		5717280b78f6e99cf3008aa0c5e1e1deb3b00eea3ce3b5fa0924ed8ecab2f6f9)
    if [[ -r $sourcemodTarFile ]]; then
        tar xzf "$sourcemodTarFile" -C "$SM_TARGET_DIR"
    else
        error <<< "Install Sourcemod(https://www.sourcemod.net/)"
        return 1
    fi
    local metamodTarFile=$(Core.Sourcemod::downloadFile \
    	https://mms.alliedmods.net/mmsdrop/1.11/mmsource-1.11.0-git1148-linux.tar.gz \
		187dc6ecc398c1df7b5c001442e5e44f9d3179aabce1738e24099b5907c36b2c)
    if [[ -r $metamodTarFile ]]; then
        tar xzf "$metamodTarFile" -C "$SM_TARGET_DIR"
    else
        error <<< "Install Metamod(https://www.sourcemm.net/)"
        return 1
    fi
    success <<< "Install Sourcemod and Metamod successfully"
}


Core.Sourcemod::install() {
	PLUGINS_SOURCE_DIR="$THIS_DIR/program/Core/Sourcemod/plugins"
	: "plugins/$1"
	try Core.Sourcemod.$1::install
}