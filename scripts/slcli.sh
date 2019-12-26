#! /bin/bash
#set -vx
PATH=/sbin:/usr/sbin:/bin:/usr/bin
DESC="Squeezebox CLI wrapper"
SL_NAME=DietPiBox
SB_SERVER_IP="127.0.0.1"
SB_SERVER_CLI_PORT="9090"
SB_SERVER_WEB_PORT="9000"
# waiting for our Server to get ready for telnet
until $(nc -z $SB_SERVER_IP $SB_SERVER_CLI_PORT); do
  echo "Server seems not yet ready at $SB_SERVER_IP:$SB_SERVER_CLI_PORT"
  (( c++ )) && (( c >= 5 )) && exit 1
  sleep 5
done

if  [ ! -z "$1" ]; then
    CMD="$@"
    printf "$CMD\nexit\n" | nc -w 5 $SB_SERVER_IP $SB_SERVER_CLI_PORT \
    | sed -e 's/ /|/g' \
    | sed -e 's/\x27/\\\\x27/g' \
    | sed -e 's/%\([0-9A-F][0-9A-F]\)/\\\\\x\1/g' | xargs echo -e \
    | sed -e 's/|/\t/g' \
    | sed -r 's/(id:[0-9]+)/\n\1 /g' \
    | sed -r 's/(count:[0-9]+)$/\n\1/g'
#   | sed -e "s/%\([0-9A-F][0-9A-F]\)/\\\\\x\1/g" | xargs echo -e \

else
    echo "No command to pass."
fi

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



