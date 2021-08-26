#! /bin/bash
## This script intended for automatic tagging and Music library management
## It does not resolve all the conditions but keeps it fully automatic
## In case you see some files stuck in the download dir ${DWNLDIR},
## run beets  manually in interactive mode:
## 1. Place config.yaml from ../config.bak/ to ~/.config/beets, which is default; adjust library and target directory params as needed
## 2. Run interactively with:
##   beet import /mnt/dietpi_userdata/downloads
## (the last param is path to source untagged music from)

PATH=/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/bin/
BEETSDIR="$(dirname $0)/beetscfg"
DWNLDIR=/mnt/dietpi_userdata/downloads

# We need internet access so first checking for discharging UPS state (see upslog.sh)
[[ -s /tmp/upsstate && $(cat /tmp/upsstate) -le 5 ]] && exit 3

#renaming
#cd $DWNLDIR
#ls $DWNLDIR | awk -F"\%2F" '/\.mp3\?/ {print $4}'
#for i in *=exp=*; do j=$( echo $i | awk -F"\%2F" '{print $4".mp3"}'); mv "$i" "$j"; done

#tagging:
# beet import -qs /mnt/dietpi_userdata/downloads/
echo "$(date) INFO: First run: importing to temporary DB as is"
/usr/local/bin/beet --config $BEETSDIR/config.yaml import $DWNLDIR
#/usr/local/bin/beet --config $BEETSDIR/config.yaml bad
echo "$(date) INFO: Second run: fingerprinting in the temporary DB"
/usr/local/bin/beet --config $BEETSDIR/config.yaml fingerprint
echo "$(date) INFO: Third run: export successful matches to main DB"
/usr/local/bin/beet --config $BEETSDIR/export.yaml import $DWNLDIR
echo "$(date) INFO: Clean up"
/usr/local/bin/beet --config $BEETSDIR/config.yaml update
/usr/local/bin/beet --config $BEETSDIR/config.yaml submit

exit 0

#Commands:
#  bad               check for corrupt or missing files
#  clearart          remove images from file metadata
#  config            show or edit the user configuration
#  duplicates (dup)  List duplicate tracks or albums.
#  embedart          embed image files into file metadata
#  extractart        extract an image from file metadata
#  fetchart          download album art
#  fields            show fields available for queries and format strings
#  fingerprint       generate fingerprints for items without them
#  help (?)          give detailed help on a specific sub-command
#  import (imp, im)  import new music
#  list (ls)         query the library
#  mbsync            update metadata from musicbrainz
#  modify (mod)      change metadata fields
#  move (mv)         move or copy items
#  remove (rm)       remove matching items from the library
#  replaygain        analyze for ReplayGain
#  stats             show statistics about the library or a query
#  submit            submit Acoustid fingerprints
#  update (upd, up)  update the library
#  version           output version information
#  write             write tag information to files

# beet bad
##The badfiles plugin adds a beet bad command to check for missing and corrupt files.
##First, enable the badfiles plugin (see Using Plugins). 

#beet mbsync
##This plugin provides the mbsync command, which lets you fetch metadata from MusicBrainz 
##for albums and tracks that already have MusicBrainz IDs
##-p (--pretend) -M (--nomove) -W (--nowrite)
##To customize the output of unrecognized items, use the -f (--format)

#beet submit
##run beet submit. (You can also provide a query to submit a subset of your library.) 
##The command will use stored fingerprints if they’re available; 
##otherwise it will fingerprint each file before submitting it.

#beet fingerprint
##You can also use the beet fingerprint command to generate fingerprints for items already in your library. 
##(Provide a query to fingerprint a subset of your library.) 
##The generated fingerprints will be stored in the library database. 
##If you have the import.write config option enabled, they will also be written to files’ metadata.

#beet replaygain [-Waf] [QUERY]
##The -a flag analyzes whole albums instead of individual tracks. 
##Provide a query (see Queries) to indicate which items or albums to analyze. 
##Files that already have ReplayGain values are skipped unless -f is supplied. 
##Use -w (write tags) or -W (don’t write tags) to control whether ReplayGain tags are written into the music files, 
##or stored in the beets database only

#beet fetchart [-f] [query]
##By default, the command will only look for album art when the album doesn’t already have it; 
##the -f or --force switch makes it search for art in Web databases regardless.
##beet fetchart [-q] [query]
##By default the command will display all results, 
##the -q or --quiet switch will only display results for album arts that are still missing.

#beet embedart
#beet extractart
#beet clearart
