#! /bin/bash
#set -vx
PATH=/sbin:/usr/sbin:/bin:/usr/bin
#avoiding another instance of cycled scipt
[[ $(/usr/bin/pgrep -a sh | grep -cF $(basename $0)) -gt 2 && -z "$1" ]] && exit 3
#
DESC="Squeezebox CLI wrapper"
SL_NAME=DietPiBox
SB_SERVER_IP="127.0.0.1"
SB_SERVER_CLI_PORT="9090"
SB_SERVER_WEB_PORT="9000"
SL_LOG=/var/log/squeezelite.log
SLCLI="$(dirname $0)/slcli.sh"
SLFUNC="$(dirname $0)/slfunctions.sh"
# waiting for our Server to get ready for telnet
until $(nc -z $SB_SERVER_IP $SB_SERVER_CLI_PORT); do
  echo "Server seems not yet ready at $SB_SERVER_IP:$SB_SERVER_CLI_PORT"
#  (( c++ )) && (( c >= 5 )) && exit 1
  sleep 5
done

# expected cmd variants: 
#b8%3A27%3Aeb%3Ad7%3Ae7%3Aae playlist open file%3A%2F%2F%2Fmnt%2Fdietpi_userdata%2FMusic%2FHozier%2FNFWMB%2520MP3_320kbps.mp3
#b8%3A27%3Aeb%3Ad7%3Ae7%3Aae playlist newsong NFWMB 7
#b8%3A27%3Aeb%3Ad7%3Ae7%3Aae playlist jump %2B1   
#b8%3A27%3Aeb%3Ad7%3Ae7%3Aae playlist stop
#b8%3A27%3Aeb%3Ad7%3Ae7%3Aae playlist open file%3A%2F%2F%2Fmnt%2Fdietpi_userdata%2FMusic%2FThe%2520Last%2520Shadow%2520Puppets%2FStanding%2520Next%2520to%2520Me%2520MP3_320kbps.mp3
#b8%3A27%3Aeb%3Ad7%3Ae7%3Aae playlist open file%3A%2F%2F%2Fmnt%2Fdietpi_userdata%2FMusic%2FThe%2520Last%2520Shadow%2520Puppets%2FStanding%2520Next%2520to%2520Me%2520MP3_320kbps.mp3
#b8%3A27%3Aeb%3Ad7%3Ae7%3Aae playlist newsong Standing%20Next%20to%20Me 8
#b8%3A27%3Aeb%3Ad7%3Ae7%3Aae pause   
#b8%3A27%3Aeb%3Ad7%3Ae7%3Aae playlist pause 1
#b8%3A27%3Aeb%3Ad7%3Ae7%3Aae menustatus ARRAY(0x4ddbea0) add b8%3A27%3Aeb%3Ad7%3Ae7%3Aae
#listen 1
#prefset server sn_session	18892543:1WPgaQBz10HGNZqjzj2l9TXVWvw
#prefset server sn_timediff	0
#prefset server sn_disabled_plugins	ARRAY(0x6e63e68)
#b8%3A27%3Aeb%3Ad7%3Ae7%3Aae	mixer	volume	+5
#b8%3A27%3Aeb%3Ad7%3Ae7%3Aae	playlist	addtracks	track.id=929		index:10
#b8%3A27%3Aeb%3Ad7%3Ae7%3Aae	playlistcontrol	cmd:insert	track_
#id:1952 	play_index:0	
#count:1
#rescan
#rescan	done
#favorites	add	url:deezer://630594342.mp3	title:HILF MIR	
#count:1
#favorites	changed
#b8:27:eb:d7:e7:ae	playlist	stop

function do_action(){
[[ -z ${1%%*%3A*} ]] && shift
local -a line=("$@")
#expected: cmd as [0], action as [1]
#echo "got cmd: ${line[0]} action: ${line[1]}"

# filter options start here

 # option to add more tracks in case latest is started
 if [[ "${line[0]}" == "playlist" &&  "${line[1]}" == "newsong" ]]; then 
    local -A statushash
    #b8:27:eb:d7:e7:ae	status
    #player_name:DietPiBox	player_connected:1	player_ip:127.0.0.1:47828	power:1	signalstrength:0
    #mode:stop	time:0	rate:1	duration:215.144	can_seek:1	mixer volume:100	playlist repeat:0	playlist shuffle:0	playlist mode:off
    #seq_no:0	playlist_cur_index:9	playlist_timestamp:1577477630.44775	playlist_tracks:10
    for value in $($SLCLI status); do 
	statushash["${value%%:*}"]="${value#*:}";
    done
    # now, if last track in playlist has just started, let's add more stuff:
    local remain=$((  statushash["playlist_tracks"] - statushash["playlist_cur_index"] ))
    if [[ $remain -eq 1 ]]; then
     # try Deezer flow in case Internet connection available or continue local random play otherwise
     curl http://www.mysqueezebox.com/ -s -f -o /dev/null && $SLFUNC play_fav "Deezer"  || $SLFUNC play_random 10 100 
     #$SLFUNC play_random 10 100
     #$SLCLI randomplay tracks
     #$SLFUNC play_fav "Deezer"
    fi
    unset statushash
 fi

}

function clear_output(){
printf "%s\t" $(date +%Y%m%d_%H%M%S); echo -e "$@" \
    | sed -e 's/ /|/g' \
    | sed -e 's/\x27/\\\\x27/g' \
    | sed -e 's/%\([0-9A-F][0-9A-F]\)/\\\\\x\1/g' | xargs echo -e \
    | sed -e 's/|/\t/g' \
    | sed -r 's/(id:[0-9]+)/\n\1 /g' \
    | sed -r 's/(count:[0-9]+)$/\n\1/g'
#   | sed -e "s/%\([0-9A-F][0-9A-F]\)/\\\\\x\1/g" | xargs echo -e \
}

# main loop
printf "listen 1\n" | nc $SB_SERVER_IP $SB_SERVER_CLI_PORT \
 | ( while read line; do clear_output "$line"; do_action $line; 
     done ) >>$SL_LOG

exit $?


# Useful commands

# player count ? 
#The "player count ?" query returns the number of players connected to the server. 

# player name ?
# connected ?

# sync 
# The "sync" command specifies the player to synchronise with the given playerid. 

# power <0|1|?|>
# The "power" command turns the player on or off. Use 0 to turn off, 1 to turn on, ? to query and no parameter to toggle the power state of the player. 

# mixer volume <0 .. 100|-100 .. +100|?> 
# mixer bass <0 .. 100|-100 .. +100|?> 
# mixer treble <0 .. 100|-100 .. +100|?>
# mixer pitch <80 .. 120|-40 .. +40|?>

# mode ?
# play
# pause <0|1|>
# stop

# playlist play 
# playlist add /music/abba/01_Voulez_Vous.mp3
# playlist insert <item> 
# playlist move <fromindex>
# playlist deleteitem <item>
# playlist clear

# status
# serverstatus

# info total artists ? 
# info total albums ? 
# info total songs ? 

# rescan <|playlists|external|full singlefolder|?>
# rescanprogress
# abortscan 
# wipecache
# The "wipecache" command allows the caller to have the server rescan its music library, reloading the music file information. 
# This differs from the "rescan" command in that it first clears the tag database. 
# During a rescan triggered by "wipecache", "rescan ?" returns true. 



