#! /bin/bash
# Script based on original version as follows:
# Script version 1.13
# Tutorial & credits: http://www.gerrelt.nl/RaspberryPi/wordpress/tutorial-installing-squeezelite-player-on-raspbian/
# SL_DOWNLOAD_URL="http://www.gerrelt.nl/RaspberryPi/squeezelite_ralph/squeezelite-armv6hf.tar.gz"
# SL_DOWNLOAD_URL="http://ralph_irving.users.sourceforge.net/pico/squeezelite-armv6hf-noffmpeg"
# alternative (older version): http://squeezelite-downloads.googlecode.com/git/squeezelite-armv6hf

###### SETTINGS ###########################################################

# PATH should only include /usr/* if it runs after the mountnfs.sh script
PATH=/sbin:/usr/sbin:/bin:/usr/bin
DESC="Squeezebox client helper"
NAME="squeezelite"
VERBOSE=false

#play_random function requires DatabaseQuery LMS plugin with customized query "sqlquery".
#Edit it or create new and adjust the SQLQUERY_NAME setting
#SQL query listing:
#	select url from tracks WHERE url LIKE 'file://%'and content_type != 'dir' order by RANDOM() limit 1
# http://${SB_SERVER_IP}:${SB_SERVER_WEB_PORT}/plugins/DatabaseQuery/databasequery_list.html
SQLQUERY_NAME="sqlquery"

# get hostname which can be used as hostname
# watch out, on raspbian, you can only use letters, numbers and hyphens (minus sign, "-"). And nothing else!
SL_NAME=DietPiBox
#SL_NAME=DietPi-Squeezelite
#SL_NAME=$(hostname -s)
#[ -n "$SL_NAME" ] || SL_NAME=SqueezelitePlayer

WEB_HOST="http://www.mysqueezebox.com"

# Squeezebox server port for sending play and power off commands
SB_SERVER_IP="127.0.0.1"
SB_SERVER_CLI_PORT="9090"
SB_SERVER_WEB_PORT="9000"
# waiting for our Server to get ready for telnet
until $(nc -z $SB_SERVER_IP $SB_SERVER_CLI_PORT); do
  echo "Server seems not yet ready at $SB_SERVER_IP:$SB_SERVER_CLI_PORT"
  sleep 5
done



# Get user settings for squeezelite (it should contain settings like SL_SOUNDCARD, SB_SERVER_IP, SL_ALSA_PARAMS etc.)
# For the default script, see: http://www.gerrelt.nl/RaspberryPi/squeezelite_settings.sh
#SL_SETTINGS=/usr/local/bin/squeezelite_settings.sh
#if [ ! -x "$SL_SETTINGS" ]
#then
#  echo "Error: script $SL_SETTINGS not found."
#  exit 2
#else
#  . $SL_SETTINGS
#fi
#do_set_playerprefs(){
# <playerid> playerpref <prefname|namespace:prefname> <prefvalue|?>
#The "playerpref" command allows the caller to set and query the server's internal player-specific preferences values.
#If you want to query/set a preference from an other namespace than "server" (eg. a plugin), you'll have to prepend the desired namespace to the prefname.
#Examples:
#    Request: "04:20:00:12:23:45 playerpref doublesize ?"
#    Response: "04:20:00:12:23:45 playerpref doublesize 1"
#    Request: "04:20:00:12:23:45 playerpref doublesize 0"
#    Response: "04:20:00:12:23:45 playerpref doublesize 0"
#playerpref playtrackalbum 0
#playerpref digitalVolumeControl 0
#playerpref replayGainMode 3
#playerpref defeatDestructiveTouchToPlay 2
#playerpref plugin.dontstopthemusic:provider PLUGIN_DEEZER_SMART_RADIO
#}


#########################################################################################


###### FUNCTIONS ########################################################################
###############################################



# Function for telling the player to start playing at a certain volume (optional)
# cronjob:
#0 7 * * 1-5 sudo /etc/init.d/squeezelite play 40
#
do_play()
{
    VOLUME=$1
    # This function only works if the Squeezebox server IP is set
    if  [ ! -z "$SB_SERVER_IP" ]; then
      echo "Sending play command to Squeezebox server"
      printf "$SL_NAME play\nexit\n" | nc -w 10 $SB_SERVER_IP $SB_SERVER_CLI_PORT > /dev/null
      if  [ ! -z "$1" ]; then
         # volume has to be set
         do_set_volume "$VOLUME"
      fi
    else
      echo "The IP address of the Squeezebox server is not set (variable: SB_SERVER_IP should be set). This is needed for the play function."
    fi
}


do_play_url()
{
    SEARCHFOR=$1
    VOLUME=$2
    # This function only works if the Squeezebox server IP is set
    if  [ ! -z "$SB_SERVER_IP" ]; then
      echo "Sending URL play command to Squeezebox server"
      printf "$SL_NAME playlist play $SEARCHFOR\nexit\n" | nc -w 10 $SB_SERVER_IP $SB_SERVER_CLI_PORT
      if  [ ! -z "$2" ]; then
         # volume has to be set
         do_set_volume "$VOLUME"
      fi
    else
      echo "The IP address of the Squeezebox server is not set (variable: SB_SERVER_IP should be set). This is needed for the function."
    fi
}

do_play_randommix()
{
    VOLUME=$1
    # This function only works if the Squeezebox server IP is set
    if  [ ! -z "$SB_SERVER_IP" ]; then
      echo "Sending RandomMix play command to Squeezebox server"
      printf "$SL_NAME randomplay tracks\nexit\n" | nc -w 10 $SB_SERVER_IP $SB_SERVER_CLI_PORT > /dev/null
      if  [ ! -z "$1" ]; then
         # volume has to be set
         do_set_volume "$VOLUME"
      fi
    else
      echo "The IP address of the Squeezebox server is not set (variable: SB_SERVER_IP should be set). This is needed for the play function."
    fi
}

## NOTE: this function requires additional setup for LMS - see the SQLQUERY_NAME setting comments above
do_play_random()
{
    VOLUME=$2
    ITEMS=$( [[ ! -z "$1" ]] && echo "$1" || echo 1 )
    # This function only works if the Squeezebox server IP is set
    if  [ ! -z "$SB_SERVER_IP" ]; then
      echo "Sending random track play command to Squeezebox server"
#     printf "$SL_NAME playlist play $(curl --raw --url 'http://$SB_SERVER_IP:$SB_SERVER_WEB_PORT/plugins/DatabaseQuery/databasequery_executedataquery.html?type=sqlquery&player=$SL_NAME&as=csv' 2>/dev/null |grep -m 1 'file://')\nexit\n" | nc -w 5 $SB_SERVER_IP $SB_SERVER_CLI_PORT >/dev/null
      RND_ID=$(curl --raw --url "http://${SB_SERVER_IP}:${SB_SERVER_WEB_PORT}/plugins/DatabaseQuery/databasequery_executedataquery.html?type=${SQLQUERY_NAME}&player=${SL_NAME}&as=csv" 2>/dev/null |grep -m ${ITEMS} 'file://' | sed 's/%/%%/g')
#     echo "RND_ID:" $RND_ID
      for i in ${RND_ID}; do
      printf "$SL_NAME playlist insert ${i}\nexit\n" | nc -w 5 $SB_SERVER_IP $SB_SERVER_CLI_PORT
      done
      do_play "$VOLUME"
    else
      echo "The IP address of the Squeezebox server is not set (variable: SB_SERVER_IP should be set). This is needed for the play function."
    fi
}

#
# Clears the current playlist of all songs.
#
clear_playlist()
{
    # This function only works if the Squeezebox server IP is set
    if  [ ! -z "$SB_SERVER_IP" ]; then
      echo "Sending clear playlist command to Squeezebox server"
      printf "$SL_NAME playlist clear\nexit\n" | nc -w 10 $SB_SERVER_IP $SB_SERVER_CLI_PORT > /dev/null
    else
      echo "The IP address of the Squeezebox server is not set (variable: SB_SERVER_IP should be set). This is needed for the clear_playlist function."
    fi
}

#
# Function for telling the player to stop playing
#
do_stop_playing()
{
    # This function only works if the Squeezebox server IP is set
    if  [ ! -z "$SB_SERVER_IP" ]; then
      echo "Sending stop playing command to Squeezebox server"
      printf "$SL_NAME stop\nexit\n" | nc -w 10 $SB_SERVER_IP $SB_SERVER_CLI_PORT > /dev/null
    else
      echo "The IP address of the Squeezebox server is not set (variable: SB_SERVER_IP should be set). This is needed for the stop_playing function."
    fi
}

#
# Function to set the volume
#
do_set_volume()
{
    VOLUME=$1
    # This function only works if the Squeezebox server IP is set
    if  [ ! -z "$SB_SERVER_IP" ]; then
      if  [ ! -z "$1" ]; then
         # volume has to be set
         printf "$SL_NAME mixer volume ${VOLUME}\nexit\n" | nc -w 10 $SB_SERVER_IP $SB_SERVER_CLI_PORT
      else
         echo "ERROR: set_volume needs a volume as a parameter, for example: $(basename $0) set_volume 40"
      fi
    else
      echo "The IP address of the Squeezebox server is not set (variable: SB_SERVER_IP should be set). This is needed for the play_fav function."
    fi
}



#
# Play next or previous song
#
do_play_nextprev()
{
  # This function only works if the Squeezebox server IP is set
  if  [ ! -z "$SB_SERVER_IP" ]; then
    DIRECTION=$1
    if [ -z "$DIRECTION" ]; then
       # parameter empty / not given, do a next
       DIRECTION="NEXT"
    fi

    # check if we're going forwards or backwards
    if [ "$DIRECTION" == "NEXT" ]; then
      UPDOWN="+1"
    else 
      UPDOWN="-1"
    fi
    printf "$SL_NAME  playlist index ${UPDOWN}\nexit\n" | nc -w 10 $SB_SERVER_IP $SB_SERVER_CLI_PORT
  else
    echo "The IP address of the Squeezebox server is not set (variable: SB_SERVER_IP should be set). This is needed for the play_fav function."
  fi
}
#
# Play next song
#
do_play_next()
{
  do_play_nextprev "NEXT"
}
#
# Play previous song
#
do_play_prev()
{
  do_play_nextprev "PREVIOUS"
}

#
# Function that return the favorites list
#
list_favorites() {
  # This function only works if the Squeezebox server IP is set
  if  [ ! -z "$SB_SERVER_IP" ]; then
    # Get favorites list, and echo it
    # (decode URL escape characters twice because of url)
    FAVLIST=$( printf "$SL_NAME favorites items 0 1000 want_url:1\nexit\n" | nc -w 10 $SB_SERVER_IP $SB_SERVER_CLI_PORT | sed -e 's/%\([0-9A-F][0-9A-F]\)/\\\\\x\1/g' | xargs echo -e | sed -e's/%\([0-9A-F][0-9A-F]\)/\\\\\x\1/g' | xargs echo -e | sed -r 's/ id:([0-9]+) /\n\1 /g'   | sed -r 's/ (count:[0-9]+)$/\n\1/g' )
    #'
    echo "$FAVLIST"
  else
    echo "The IP address of the Squeezebox server is not set (variable: SB_SERVER_IP should be set). This is needed for the play_fav function."
  fi
}

#
# Function to play something from the favorite list at a certain volume (optional)
# Note: replace all spaces in the favorite name with %20
#
# cronjob:
#0 7 * * 1-5 sudo /etc/init.d/squeezelite play_fav "Q-music" 100
#
do_play_fav()
{
    SEARCHFOR=$1
    VOLUME=$2
    # This function only works if the Squeezebox server IP is set
    if  [ ! -z "$SB_SERVER_IP" ]; then
      FAV_ID=$(printf "$SL_NAME favorites items 0 1000\nexit\n" | nc -w 10 $SB_SERVER_IP $SB_SERVER_CLI_PORT  | sed 's/%3A/:/g' | sed 's/ id:/\'$'\n/g' | grep -i "${SEARCHFOR}" | cut -d ':' -f1 | cut -d ' ' -f1 | head -n 1)
      echo $FAV_ID
      printf "$SL_NAME favorites playlist play item_id:${FAV_ID}\nexit\n" | nc -w 10 $SB_SERVER_IP $SB_SERVER_CLI_PORT
      if  [ ! -z "$2" ]; then
         # volume has to be set
         do_set_volume "$VOLUME"
      fi
    else
      echo "The IP address of the Squeezebox server is not set (variable: SB_SERVER_IP should be set). This is needed for the play_fav function."
    fi
}

#
# Find the currently playing favorite by stream url, mp3 filename, album, artist or genre
#
get_current_fav_id() {
  # for debugging output to stderror, otherwise it will be the result of this function!
  #echo "$FAVLIST" >&2

  # This function only works if the Squeezebox server IP is set
  if  [ ! -z "$SB_SERVER_IP" ]; then

    FAVLIST="$1" # de double quotes preserve the newlines, otherwise they will be gone..
    if [ -z "$FAVLIST" ]; then
      echo "function get_current_fav_id needs parameter FAVLIST, which contains the favorites list from function list_favorites" >&2
      return 1
    fi

    # check if it's a radio stream currently playing
    RADIO_STREAM=$(printf "$SL_NAME playlist remote ?\nexit\n" | nc -w 10 $SB_SERVER_IP $SB_SERVER_CLI_PORT | sed -e's/%\([0-9A-F][0-9A-F]\)/\\\\\x\1/g' | xargs echo -e | sed -r 's/.* ([0-9]*)$/\1/g')

    # If remote is 1, then it's a radio station, search on url.
    if [ "$RADIO_STREAM" == "1" ]
    then
      # It's a radio stream, match on url
      #
      # example output: b8:27:eb:97:75:86 path ? http://icecast.omroep.nl/3fm-sb-aac
      SEARCH_STRING="url:$(printf "$SL_NAME path ?\nexit\n" | nc -w 10 $SB_SERVER_IP $SB_SERVER_CLI_PORT | sed -e's/%\([0-9A-F][0-9A-F]\)/\\\\\x\1/g' | xargs echo -e | sed -r 's/^.* path (.*)$/\1/g' | sed -e's/%\([0-9A-F][0-9A-F]\)/\\\\\x\1/g' | xargs echo -e)"
      # Get current favorite using: $SEARCH_STRING
      # : 0 name:3FM type:audio url:http://icecast.omroep.nl/3fm-sb-aac isaudio:1 hasitems:0
      CURRENT_FAV_ID=$(echo "$FAVLIST" | grep " type:audio $SEARCH_STRING isaudio:[0-1] hasitems:[0-9]" | sed -r 's/^([0-9]+) name:.*$/\1/g')
    #'
    else
      # Remote is 0, then it's a local file.

      # Try to find mp3 filename first
      #
      # example output: b8:27:eb:97:75:86 path ? file:///share/Muziek/Muse%20-%20Drones/03%20Muse%20-%20Psycho.mp3
      SEARCH_STRING="url:$(printf "$SL_NAME path ?\nexit\n" | nc -w 10 $SB_SERVER_IP $SB_SERVER_CLI_PORT | sed -e's/%\([0-9A-F][0-9A-F]\)/\\\\\x\1/g' | xargs echo -e | sed -r 's/^.* path (.*)$/\1/g' | sed -e's/%\([0-9A-F][0-9A-F]\)/\\\\\x\1/g' | xargs echo -e)"
      # Get current favorite using: $SEARCH_STRING
      CURRENT_FAV_ID=$(echo "$FAVLIST" | grep " type:audio $SEARCH_STRING isaudio:[0-1] hasitems:[0-9]" | sed -r 's/^([0-9]+) name:.*$/\1/g')
     #'
      if [ -z "$CURRENT_FAV_ID" ]; then
        # Try album
        #
        # example output: b8:27:eb:97:75:86 album ? 2015 1 Romantische Rijn
        SEARCH_STRING="url:db:album.title=$(printf "$SL_NAME album ?\nexit\n" | nc -w 10 $SB_SERVER_IP $SB_SERVER_CLI_PORT | sed -e's/%\([0-9A-F][0-9A-F]\)/\\\\\x\1/g' | xargs echo -e | sed -r 's/^.* album (.*)$/\1/g')"
        # Get current favorite using: $SEARCH_STRING
        CURRENT_FAV_ID=$(echo "$FAVLIST" | grep " type:audio $SEARCH_STRING isaudio:[0-1] hasitems:[0-9]" | sed -r 's/^([0-9]+) name:.*$/\1/g')
      #'
      fi
      if [ -z "$CURRENT_FAV_ID" ]; then
        # Try artist
        #
        # example output: b8:27:eb:97:75:86 artist ? U2
        SEARCH_STRING="url:db:contributor.name=$(printf "$SL_NAME artist ?\nexit\n" | nc -w 10 $SB_SERVER_IP $SB_SERVER_CLI_PORT | sed -e's/%\([0-9A-F][0-9A-F]\)/\\\\\x\1/g' | xargs echo -e | sed -r 's/^.* artist (.*)$/\1/g')"
        # Get current favorite using: $SEARCH_STRING
        CURRENT_FAV_ID=$(echo "$FAVLIST" | grep " type:audio $SEARCH_STRING isaudio:[0-1] hasitems:[0-9]" | sed -r 's/^([0-9]+) name:.*$/\1/g')
      #'
      fi
      if [ -z "$CURRENT_FAV_ID" ]; then
        # Try genre
        #
        # example output: b8:27:eb:97:75:86 genre ? Alt. Rock
        SEARCH_STRING="url:db:genre.name=$(printf "$SL_NAME genre ?\nexit\n" | nc -w 10 $SB_SERVER_IP $SB_SERVER_CLI_PORT | sed -e's/%\([0-9A-F][0-9A-F]\)/\\\\\x\1/g' | xargs echo -e | sed -r 's/^.* genre (.*)$/\1/g')"
        # Get current favorite using: $SEARCH_STRING
        CURRENT_FAV_ID=$(echo "$FAVLIST" | grep " type:audio $SEARCH_STRING isaudio:[0-1] hasitems:[0-9]" | sed -r 's/^([0-9]+) name:.*$/\1/g')
      #'
      fi
    fi
    # return the favorite id
    echo "$CURRENT_FAV_ID"

  else
    echo "The IP address of the Squeezebox server is not set (variable: SB_SERVER_IP should be set). This is needed for the play_fav function."
  fi
}

#
# Plays the next or previous favorite
#
play_nextprev_favorite() {

  # This function only works if the Squeezebox server IP is set
  if  [ ! -z "$SB_SERVER_IP" ]; then

    DIRECTION=$1
    if [ -z "$DIRECTION" ]; then
       # parameter empty / not given, do a next
       DIRECTION="NEXT"
    fi
    # Get favorite list
    FAVLIST=$(list_favorites)
    #echo "$FAVLIST"
    # get number of favorites
    NUMBER_FAVS=$(echo "$FAVLIST" | grep "^count:[0-9]*" | sed -r 's/^count:([0-9]*)$/\1/g')
    #echo Number of favorites: $NUMBER_FAVS
    # this function uses a temporary file to keep track of the current favorite, once it's determind with the get_current_fav_id function
    # check if file with current favorite exists
    CURFAV_FILE="/run/squeezelite_curfav.txt"
    if [ -f "$CURFAV_FILE" ]; then
      # if yes, then use it to determine next favorite
      #echo "$CURFAV_FILE found."
      
      FAV_NUMBER=$(cat $CURFAV_FILE)
      
    else
      # if no, then search the favorite with current song
      #echo "$CURFAV_FILE not found."
      FAV_NUMBER=$(get_current_fav_id "$FAVLIST")
    fi
    if [ -z "$FAV_NUMBER" ]; then
      # no current ID found, so set it to the first favorite
      FAV_NUMBER=0
      #echo Current favorite not found, go to: $FAV_NUMBER
    else
      # Get the favorite number
      
      # check if we're going forwards or backwards
      if [ "$DIRECTION" == "NEXT" ]; then
        ((FAV_NUMBER++))
      else 
        ((FAV_NUMBER--))
      fi

      # If the last favorite number is reached, go to the first (0) one.
      if [ "$FAV_NUMBER" == "$NUMBER_FAVS" ]; then
        FAV_NUMBER=0
      fi
      # If the first favorite number (0) was reached, go to the last one.
      if [ "$FAV_NUMBER" == "-1" ]; then
        FAV_NUMBER=$((NUMBER_FAVS-1))
      fi

    fi
    #echo Current favorite ID: $FAV_NUMBER
    # Write the new favorite ID to the temporary file
    echo $FAV_NUMBER > $CURFAV_FILE
    # Play the new favorite ID:
    printf "$SL_NAME favorites playlist play item_id:${FAV_NUMBER}\nexit\n" | nc -w 10 $SB_SERVER_IP $SB_SERVER_CLI_PORT > /dev/null
  else
    echo "The IP address of the Squeezebox server is not set (variable: SB_SERVER_IP should be set). This is needed for the play_fav function."
  fi
}

#
# Plays the next favorite
#
play_next_favorite() {
  play_nextprev_favorite "NEXT"
}
#
# Plays the previous favorite
#
play_prev_favorite() {
  play_nextprev_favorite "PREVIOUS"
}



do_check_online(){
    curl -sSI --connect-timeout 3 $WEB_HOST 2>&1
    return $?
}


#########################################################################################


###### OPTIONS ########################################################################
###############################################

case "$1" in
  webcheck)
    if $VERBOSE; then 
	echo "Checking if $WEB_HOST reachable"
    fi
    WEB_HOST_STATE=$( do_check_online )
    case "$?" in
        0)  echo "$WEB_HOST ok"; exit 0 ;;
        *)  echo "Error '$WEB_HOST_STATE' while trying to reach the $WEB_HOST"; exit 1 ;;
    esac
    ;;
  autoplay)
    clear_playlist
    if $VERBOSE; then 
	echo "Checking if $WEB_HOST reachable"
    fi
    WEB_HOST_STATE=$( do_check_online )
    case "$?" in
#        0) do_play_fav "type:audio" ;;
        0) do_play_url "deezer://flow.dzr" ;;
        *) do_play_random ;;
    esac
    ;;
  play_random)
    echo "Play random $2 song(s) with volume $3"
    do_play_random "$2" "$3"
    ;;
  play_randommix)
    echo "Play tracks with randommix plugin  with volume $2"
    do_play_randommix "$2"
    ;;
  play_url)
    echo "Play $2 with volume $3"
    do_play_url "$2" "$3"
    ;;
  play)
    echo "Play with volume $2"
    do_play "$2"
    ;;
  play_nextprev)
    echo "Play $2 (NEXT|PREVIOUS) song"
    do_play_nextprev $2
    ;;
  play_next)
    echo "Play next song"
    do_play_next
    ;;
  play_prev)
    echo "Play previous song"
    do_play_prev
    ;;
  play_fav)
    echo "Play favorite $2 with volume $3"
    do_play_fav "$2" "$3"
    ;;
  list_favorites)
    echo "List all favorites"
    list_favorites
    ;;
  get_current_fav_id)
    echo "Get currently playing favorite from given favorite list"
    get_current_fav_id $2
    ;;
  play_nextprev_favorite)
    echo "Play $2 (NEXT|PREVIOUS) favorite"
    play_nextprev_favorite $2
    ;;
  play_next_favorite)
    echo "Play next favorite"
    play_next_favorite
    ;;
  play_prev_favorite)
    echo "Play previous favorite"
    play_prev_favorite
    ;;
  clear_playlist)
    echo "Clear current playlist"
    clear_playlist
    ;;
  stop_playing)
    echo "Stop playing"
    do_stop_playing
    ;;
  set_volume)
    echo "Set volume to $2"
    do_set_volume "$2"
    ;;
#  status)
#       status_of_proc "$DAEMON" "$NAME" && exit 0 || exit $?
#       ;;
  *)
    #echo "Usage: $0 {start|stop|update|play|play_fav|stop_playing|set_volume|status|restart|force-reload}" >&2
    echo "Usage: $0 {list_favorites|get_current_fav_id|play|play_next[prev]|play_fav|play_next[prev]_favorite|play_url|play_random|play_randommix|stop_playing|clear_playlist|set_volume|webcheck}" >&2
    exit 3
    ;;
esac

:
