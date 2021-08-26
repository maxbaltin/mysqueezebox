#! /bin/bash
###
### Script intended to re-tag already downloaded MP3 files in the DWNLD_DIR 
### by searching already captured tags or directly from Squeezebox Server log
###
### PRE_REQS: wget, mid3v2 (pip install mutagen)
###

### We need internet and some services to run so first checking for discharging UPS state (see upslog.sh)
[[ -s /tmp/upsstate && $(cat /tmp/upsstate) -lt 7 ]] && exit 3

### Setting some essential vars
PATH=/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/bin
DWNLDIR=/mnt/dietpi_userdata/downloads
TMPDIR=/tmp
TAGGER=$(which mid3v2)
USERAGENT="iTunes/4.7.1 (Linux; N; Debian; armv7l-linux; EN; utf8) SqueezeCenter, Squeezebox Server, Logitech Media Server/7.9.1/1522157629"
TAGEXT="tmp.tags"
MP3EXT="mp3"

### To collect valuable info on downloading, enable Deezer DEBUG level logging
### in Squeezebox Server - Advanced - Logging settings, don't forget to mark checkbox of applying log settings on restart
SQUEEZEBOXLOG=/var/log/squeezeboxserver/error.log
SQUEEZEBOXBAK=/var/log/squeezeboxserver/error.log.1
#SQUEEZEBOXBAK=/mnt/dietpi-backup/logfile_storage/squeezeboxserver/error.log

SLCLI="$(dirname $0)/slcli.sh"
declare -A TAGS

### FUNCTIONS ###

do_tag() {
#
# TODO: get rid on global $FILENAME var
#
# function receives full path to file as $1
# PRE-REQ: TAGS named array pre-populated
# will use /usr/bin/mid3v2
    #-a, --artist=ARTIST artist information (TPE1).
    #-A, --album=ALBUM  album information (TALB).
    #-t, --song=TITLE title information (TIT2).
    #-p, --picture=<FILENAME:DESCRIPTION:IMAGE-TYPE:MIME-TYPE>  attached picture (APIC). Everything except the filename can be omitted in which case default values will be used.
if  [[  -f "$1" && -x "${TAGGER}" ]];  then
    echo "$(date) INFO: Tagging file: $1"
    [[ -z $( mid3v2 -l "$1" | grep -F 'TPE1' ) ]] &&  /usr/local/bin/mid3v2 --artist="${TAGS['artist_name']}" "$1"
    [[ -z $( mid3v2 -l "$1" | grep -F 'TIT2' ) ]] &&   /usr/local/bin/mid3v2 --song="${TAGS['title']}" "$1"
    [[ -z $( mid3v2 -l "$1" | grep -F 'TALB' ) ]] &&  /usr/local/bin/mid3v2  --album="${TAGS['album_name']}" "$1"
    if [[ -z $( mid3v2 -l "$1" | grep -F 'APIC' ) ]]; then
     wget --no-verbose -U "$USERAGENT" -O "${TMPDIR}/${FILENAME}.jpg" ${TAGS['cover']}
     /usr/local/bin/mid3v2 --picture="${TMPDIR}/${FILENAME}.jpg" "$1"
    fi
else
    echo "ERROR: Tagging error. Tag binary: ${TAGGER}, target file: $1"
fi
}

echo "$(date) INFO: Starting re-tagging ${DWNLDIR}/*.${MP3EXT} files"

for file in ${DWNLDIR}/*.${MP3EXT}; do
  if [[ -r "$file" ]]; then
    FILENAME=$( basename "${file%.*}" )
    echo "$(date) INFO: Next file name ${FILENAME}, path ${file}"
    ### collecting info from .$TAGEXT files or LMS log
    [[ -r ${DWNLDIR}/${FILENAME}.${TAGEXT} ]] \
	    && TAGFILE="${DWNLDIR}/${FILENAME}.${TAGEXT}" \
	    || TAGFILE="${TMPDIR}/${FILENAME}.${TAGEXT}"
    echo "$(date) DEBUG: checking and fixing ${TAGFILE}"
    ### grepping squeezeboxserver's deezer debug log with match limit 1 and 9 lines before the match, see .tags file samples
    ### utf decoding looks ugly, this is due to local awk implementation - no gensub, no back-reference supported, no {n,m} in regexp
    if  ! $(grep -qm1 [[:alnum:]] "${TAGFILE}") && [ -f $SQUEEZEBOXLOG ]; then
      printf "%b\n" "$(grep -F -m1 -B9 "${FILENAME}" $SQUEEZEBOXLOG | awk -F' => |,$' '{gsub(/ /,"",$1); gsub(/\\x{/,"\\u0",$2); gsub(/\\x/,"\\u00",$2); gsub(/}/,"",$2); printf "%s\n", $1"\t"$2}')" >$TAGFILE
    fi
    if  ! $(grep -qm1 [[:alnum:]] "${TAGFILE}")  && [ -f $SQUEEZEBOXBAK ]; then
      printf "%b\n" "$(grep -F -m1 -B9 "${FILENAME}" $SQUEEZEBOXBAK | awk -F' => |,$' '{gsub(/ /,"",$1); gsub(/\\x{/,"\\u0",$2); gsub(/\\x/,"\\u00",$2); gsub(/}/,"",$2); printf "%s\n", $1"\t"$2}')" >$TAGFILE
    fi
    ### parsing tagged file to hash array
    echo "$(date) DEBUG: parsing ${TAGFILE}"
    if  [[ -r ${TAGFILE} ]] && $(grep -qm1 [[:alnum:]] "${TAGFILE}"); then
        echo "$(date) DEBUG: tag file content:"
	cat ${TAGFILE}
        while read name val; do TAGS[$name]=$( echo $val | sed 's/"//g' ); done <$TAGFILE
	for k in ${!TAGS[*]}; do echo "$k - ${TAGS[$k]}"  ; done
    else
	echo "File not exists, empty or not readable"
    fi
    ### If tags collected, renamimg file to meaningful name and calling tagging function
    if [[ -v TAGS[@] ]] && [[ -n TAGS['artist_name'] ]] && [[ -n TAGS['title'] ]]; then
       do_tag "${file}"
       echo "$(date) DEBUG: Rename file to ${DWNLDIR}/${TAGS['artist_name']} - ${TAGS['title']}.${MP3EXT}" 
       #movinig tmp file to download location for beets to proceed, removing special characters from filenames
       # ${myvar//[\/\:\"\*\<\>\?\|\\[:cntrl:]]/,}
       mv "${file}" "${DWNLDIR}/${TAGS['artist_name']//[\/\:\"\*\<\>\?\|\\[:cntrl:]]/,} - ${TAGS['title']//[\/\:\"\*\<\>\?\|\\[:cntrl:]]/,}.${MP3EXT}"
    fi
  fi
done

echo "$(date) DEBUG: Script $0 completed"

