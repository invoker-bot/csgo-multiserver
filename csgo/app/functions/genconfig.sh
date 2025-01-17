#! /bin/bash
## vim: noet:sw=0:sts=0:ts=4

# (C) 2016-2017 Maximilian Wende <dasisdormax@mailbox.org>
#
# This file is licensed under the Apache License 2.0. For more information,
# see the LICENSE file or visit: http://www.apache.org/licenses/LICENSE-2.0




App::generateServerConfig () {
	disclaimer () { cat <<-EOF ; }
		// This file was generated by csgo-multiserver, licensed under the Apache License 2.0
		// See https://github.com/dasisdormax/csgo-multiserver for more information

	EOF

	gamemodenames () {
		GTN="unknown"
		GMN="unknown"
		case $GAMETYPE in
			0)	GTN="classic"
				(( GAMEMODE == 0 )) && GMN="casual"
				(( GAMEMODE == 1 )) && GMN="competitive"
				(( GAMEMODE == 2 )) && GMN="scrimcomp2v2"
				(( GAMEMODE == 3 )) && GMN="scrimcomp5v5";;
			1)	GTN="gungame"
				(( GAMEMODE == 0 )) && GMN="gungameprogressive"
				(( GAMEMODE == 1 )) && GMN="gungametrbomb"
				(( GAMEMODE == 2 )) && GMN="deathmatch";;
			2)	GTN="training"
				(( GAMEMODE == 0 )) && GMN="training";;
			3)	GTN="custom"
				(( GAMEMODE == 0 )) && GMN="custom";;
			4)	GTN="cooperative"
				(( GAMEMODE == 0 )) && GMN="cooperative"
				(( GAMEMODE == 1 )) && GMN="coopmission";;
			5)  GTN="skirmish"
				(( GAMEMODE == 0 )) && GMN="skirmish";;
		esac
	}

	workshop_mapgroup () {
		[[ $WORKSHOP_COLLECTION_ID ]] || return 0
		local URL
		local DATA
		local ID
		local MAPNAME
		local MAP_TRIPLE
		which jq >/dev/null 2>&1 || {
			fatal <<< "The program **jq** could not be found on your system!"
			return
		}
		[[ $APIKEY ]] || {
			error <<-EOF
				Cannot host workshop maps without a Steam Web API Key. Please get
				one at
	
				      **http://steamcommunity.com/dev/apikey**
				and insert it into your instance's **server.conf**.
			EOF
			exit 1
		}
		# Load info about collection
		echo "Loading collection $WORKSHOP_COLLECTION_ID from Workshop ..." >&2
		URL=https://api.steampowered.com/ISteamRemoteStorage/GetCollectionDetails/v1/
		DATA="collectioncount=1&publishedfileids[0]=$WORKSHOP_COLLECTION_ID"
		wget -q --post-data "$DATA" "$URL" -O "$WORKSHOP_RESULT" || {
			error <<< "Collection not found! Make sure the ID is correct and the collection is not private!"
			exit
		}
		# Parse JSON and load file details for each item in the collection
		MAPGROUP=mg_workshop
		cat <<-EOF 
			"mapgroups" { "mg_workshop" {
			"name" "mg_workshop"
			"maps" {
		EOF
		MAPS=()
		rm -f "$WORKSHOP_SUBSCRIBED"
		URL=https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/
		for ID in $(cat "$WORKSHOP_RESULT" | jq -r .response.collectiondetails[].children[].publishedfileid); do
			DATA="itemcount=1&publishedfileids[0]=$ID"
			wget -q --post-data "$DATA" "$URL" -O "$WORKSHOP_RESULT" || continue
			FILENAME="$(cat "$WORKSHOP_RESULT" | jq -r .response.publishedfiledetails[].filename)"
			[[ $FILENAME =~ .bsp$ ]] || continue
			MAPNAME="${FILENAME%.bsp}"
			MAPNAME="${MAPNAME##*/}"
			MAP_TRIPLE="workshop/$ID/$MAPNAME"
			MAPS+=( "$MAP_TRIPLE" )
			echo "Adding map $MAP_TRIPLE ..." >&2
			echo "$ID" >> "$WORKSHOP_SUBSCRIBED"
			echo "\"$MAP_TRIPLE\" \"\""
		done
		echo '}}}'
	}

	local WORKSHOP_SUBSCRIBED="$INSTANCE_DIR/csgo/subscribed_file_ids.txt"
	local WORKSHOP_RESULT="$INSTANCE_DIR/csgo/.workshop_result.txt"
	local MAPCYCLE_TXT="$INSTANCE_DIR/csgo/mapcycle.txt"
	local GAMEMODES_TXT="$INSTANCE_DIR/csgo/gamemodes_server.txt"
	local GAMEMODES_ORIG_TXT="$INSTANCE_DIR/csgo/gamemodes_server_orig.txt"
	local AUTOEXEC_CFG="$INSTANCE_DIR/csgo/cfg/autoexec.cfg"
	local SERVER_CFG="$INSTANCE_DIR/csgo/cfg/server.cfg"
	local LAST_CFG="$INSTANCE_DIR/csgo/cfg/server_last.cfg"
	local GTN
	local GMN


	######## GAMEMODES ########
	# We create our own gamemodes_server.txt
	local MARK="// <-- DO NOT DELETE OR CHANGE THIS LINE!"
	if [[ -r "$GAMEMODES_TXT" && "$(head -n1 "$GAMEMODES_TXT" 2>/dev/null)" != $MARK ]]; then
		# Backup the file
		cp -n "$GAMEMODES_TXT" "$GAMEMODES_ORIG_TXT"
	fi
	rm -f "$GAMEMODES_TXT"
	(	echo "$MARK"
		# Include original gamemodes_server.txt, including rules and mapgroups
		cat "$GAMEMODES_ORIG_TXT" 2>/dev/null

		# Calculate Gamemode names and build our entry
		gamemodenames
		disclaimer
		cat <<-EOF
			"GameModes_Server.txt"{"gameTypes"{"$GTN"{
			  "gameModes"{"$GMN"{
		EOF
		[[ $MAXPLAYERS ]] && echo "\"maxplayers\" \"$MAXPLAYERS\""
		echo "\"exec\"{\"exec\" \"server_last.cfg\"}"
		[[ $WORKSHOP_COLLECTION_ID ]] && echo '"mapgroupsMP" { "mg_workshop" "" }'
		echo "}}}}"
	) > "$GAMEMODES_TXT"
	workshop_mapgroup >> "$GAMEMODES_TXT"
	echo "}" >> "$GAMEMODES_TXT"


	######## MAPCYCLE ########
	# The map pool (and usually its order as well) when using sourcemod

	rm -f "$MAPCYCLE_TXT"
	for map in ${MAPS[@]}; do
		echo "$map" >> "$MAPCYCLE_TXT"
	done


	######## AUTOEXEC ########
	# This is executed once when starting the server

	(	disclaimer
		cat <<-EOF
			// -------- BASIC STUFF --------

			log on
			sv_password "$PASS"
			rcon_password "$RCON_PASS"

			hostname "$TITLE"

			sv_tags "$TAGS"

			// sv_lan should NEVER be set, because it disables VAC protection and
			// prevents loading of a player's inventory
			sv_lan 0

			sv_pure "$SV_PURE"
			sv_cheats "$SV_CHEATS"

			sv_mincmdrate "$TICKRATE"
			sv_minupdaterate "$TICKRATE"
			sv_minrate "$(( TICKRATE * 500 ))"
			sv_enabledownload 1
			sv_enableupload 1

			exec banned_user.cfg // Read list of banned users
		EOF

		# Downloads
		[[ $DOWNLOAD_URL	 ]] && echo "sv_downloadurl \"$DOWNLOAD_URL\""

		# Conditionals
		[[ $HOSTIP           ]] && echo "hostip \"$HOSTIP\""
		[[ $HOSTPORT         ]] && echo "hostport \"$HOSTPORT\""
		[[ $SV_SPONSOR_IMAGE ]] && echo "sv_server_graphic1 \"$SV_SPONSOR_IMAGE\""
		[[ $SV_HOST_IMAGE    ]] && echo "sv_server_graphic2 \"$SV_HOST_IMAGE\""
		[[ $TV_CAMERAMAN     ]] && echo "tv_allow_camera_man_steamid \"$TV_CAMERAMAN\""

		# GOTV specific settings ####
		(( TV_ENABLE )) && cat <<-EOF


			// -------- GOTV --------
			tv_enable 1
			tv_advertise_watchable "${TV_ADVERTISE_WATCHABLE-1}"
			tv_autorecord "${TV_AUTORECORD-0}"

			tv_password "$TV_PASS"
			tv_title "$TV_TITLE"

			tv_transmitall "$TV_TRANSMITALL"
			tv_relaytextchat "$TV_RELAYTEXTCHAT"
			tv_relayvoice "$TV_RELAYVOICE"

			tv_delaymapchange 1
			tv_deltacache 2

			mapoverview_allow_client_draw 1
		EOF

		# Additional commands, may be set through the gamemode script
		for item in "${AUTOEXEC_CUSTOM[@]}"; do
			echo "$item"
		done
	) > "$AUTOEXEC_CFG"


	#### SERVER ####
	# This file is executed on every map change

	(	disclaimer
		cat <<-EOF
			writeid // Update banned_user.cfg
			// You could add 'writeip' here, but banning ips is generally
			// not effective, with most people having dynamic ip addresses
		EOF

		# Additional commands, may be set through the gamemode script
		for item in "${MAPCHANGE_CUSTOM[@]}"; do
			echo "$item"
		done
	) > "$SERVER_CFG"


	#### LAST_CFG ####
	# This file is executed AFTER the default gamemode settings have been
	# loaded and can be used to override some of their settings

	(	disclaimer

		[[ $BOT_QUOTA ]] && echo "bot_quota \"$BOT_QUOTA\""
		[[ $SV_OCCLUDE_PLAYERS ]] && echo "sv_occlude_players \"$SV_OCCLUDE_PLAYERS\""
		[[ $TV_DELAY ]] && echo "tv_delay \"$TV_DELAY\""

		# Additional commands, may be set through the gamemode script
		for item in "${GAMEMODE_CUSTOM[@]}"; do
			echo "$item"
		done
	) > "$LAST_CFG"
}
