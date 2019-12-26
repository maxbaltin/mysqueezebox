#! /bin/bash
# We need internet and some services to run so first checking for discharging UPS state (see upslog.sh)
[[ -s /tmp/upsstate && $(cat /tmp/upsstate) -lt 7 ]] && exit 3
# Checking if previous wget still active
[[ -e /tmp/wget ]] && exit 3

PATH=/sbin:/usr/sbin:/bin:/usr/bin
FILELOG=/tmp/squeezelite.list
DWNLIST=/tmp/download.list
#BASEURL="http://cdn-proxy-$( head /dev/urandom | tr -dc a-f0-9 | head -c1 ).deezer.com"
USERAGENT="iTunes/4.7.1 (Linux; N; Debian; armv7l-linux; EN; utf8) SqueezeCenter, Squeezebox Server, Logitech Media Server/7.9.1/1522157629"
WGETLOGFILE="/var/log/wget/$( date +%y_%m_%d ).log"
## To collect valuable info on downloading, enable Deezer DEBUG level logging
## in Squeezebox Server - Advanced - Logging settings, don't forget to mark checkbox of applying log settings on restart
DEEZERDEBUG=1
DWNLDIR=/mnt/dietpi_userdata/downloads
SQUEEZEBOXLOG=/var/log/squeezeboxserver/error.log
SQUEEZEBOXBAK=/mnt/dietpi-backup/logfile_storage/squeezeboxserver/error.log
if [ $DEEZERDEBUG == 1 ]; then 
    declare -A TAGS
    SLCLI="$(dirname $0)/slcli.sh"
fi

#TODO: use SLlisten/mon script + /var/log/squeezelite.log
#TODO: get info from http://127.0.0.1:9000/plugins/deezer/trackinfo.html
#./slcli.sh genre ? |cut -f 3-
#./slcli.sh artist ? |cut -f 3-
#./slcli.sh album ? |cut -f 3-
#./slcli.sh title ? |cut -f 3-

### PRE_REQS: wget, mid3v2 (pip install mutagen)

#### todo:
#done#  build filename and prepare tags, size info from deezer debug log
#won't# check resulting filesize
#done# cross-check if song already in db BEFORE download - squeezeDB method and/or beets DB method
#test-needed# tag files with collected info
#### what if download interrupted?
#### check for backward compatibility without Deezer debug info
#### fix (.mp3) extension hardcoded in $FILENAME, on renaming (and tagging)

### FUNCTIONS ###

do_tag()
{
#function receives full path to file as $1

#kid3 doesn't run headless, requires X-Window QXcbConnection: Could not connect to display
#[[ -z $( /usr/bin/kid3-cli -c "get artist" "$1" 2>/dev/null ) ]] && /usr/bin/kid3-cli -c "set artist \"${TAGS['artist_name']}\"" "$1"
#[[ -z $( /usr/bin/kid3-cli -c "get album"  "$1" 2>/dev/null ) ]] && /usr/bin/kid3-cli -c "set album  \"${TAGS['album_name']}\"" "$1"
#[[ -z $( /usr/bin/kid3-cli -c "get title"  "$1" 2>/dev/null ) ]] && /usr/bin/kid3-cli -c "set title  \"${TAGS['title']}\"" "$1"
#/usr/bin/kid3-cli -c "set albumart ${TAGS['cover']}" "$1"

#will use /usr/bin/mid3v2
#-a, --artist=ARTIST artist information (TPE1).
#-A, --album=ALBUM  album information (TALB).
#-t, --song=TITLE title information (TIT2).
#-p, --picture=<FILENAME:DESCRIPTION:IMAGE-TYPE:MIME-TYPE>  attached picture (APIC). Everything except the filename can be omitted in which case default values will be used.
[[ -z $( /usr/bin/mid3v2 -l "$1" | grep -F 'TPE1' ) ]] && /usr/bin/mid3v2 --artist="${TAGS['artist_name']}" "$1"
[[ -z $( /usr/bin/mid3v2 -l "$1" | grep -F 'TIT2' ) ]] && /usr/bin/mid3v2 --song="${TAGS['title']}" "$1"
[[ -z $( /usr/bin/mid3v2 -l "$1" | grep -F 'TALB' ) ]] && /usr/bin/mid3v2 --album="${TAGS['album_name']}" "$1"
if [[ -z $( /usr/bin/mid3v2 -l "$1" | grep -F 'APIC' ) ]]; then
    wget --no-verbose -U "$USERAGENT" -a "$WGETLOGFILE" -O "/tmp/${FILENAME}.jpg" ${TAGS['cover']}
    /usr/bin/mid3v2 --picture="/tmp/${FILENAME}.jpg" "$1"
fi
}

do_download()
{
echo "INFO: Starting wget of $DWNLIST. Log file: $WGETLOGFILE" >>$WGETLOGFILE
#wget --no-verbose --continue --adjust-extension --wait=5 --random-wait --limit-rate=100k -U "$USERAGENT" -a "$WGETLOGFILE" -B "$BASEURL" -P $DWNLDIR -i $DWNLIST
#wget --no-verbose --continue --adjust-extension --wait=5 --random-wait -U "$USERAGENT" -B "$BASEURL" -P $DWNLDIR -i $DWNLIST
while read URL; do
    #echo $URL
    EXP=$( echo $URL|sed -rn 's/.+exp=([0-9]+).+/\1/p' )
    #'
    FILENAME=$( echo "$URL"|sed -rn 's/.+\/([a-f0-9]+)\.mp3.+/\1\.tmp/p' )
    #'
#continue if link not yet expired
if [ $EXP -ge $( date +%s  ) ]; then
    # more stuff in case deezer debug logging enabled
    if [ $DEEZERDEBUG == 1 ] && [ ! -s "/tmp/"$FILENAME".tags" ]; then
      #collecting info from LMS log
      TAGFILE="/tmp/"$FILENAME".tags"
      grep -F -m1 -B9 "$URL" $SQUEEZEBOXLOG | awk -F' => |,$' '{gsub(/ /,"",$1); print $1"\t"$2}' >$TAGFILE
      if [ ! -s $TAGFILE ]; then
        grep -F -m1 -B9 "$URL" $SQUEEZEBOXBAK | awk -F' => |,$' '{gsub(/ /,"",$1); print $1"\t"$2}' >$TAGFILE
      fi
      #parsing tagged file to hash array
      while read name val; do TAGS[$name]=$( echo $val | sed 's/"//g' ); done <$TAGFILE
    	    #for k in ${!TAGS[*]}; do echo "$k - ${TAGS[$k]}"; done
      #skipping wget if the artist+title already in the LMS database
      TAGS['lmsquery']=$( /bin/bash $SLCLI titles 0 10 tags:au  search:${TAGS['title']} |grep -iF "artist:${TAGS['artist_name']}" )
      #if [ $( /bin/bash $SLCLI titles 0 10 tags:a  search:${TAGS['title']} |grep -qF "artist:${TAGS['artist_name']}"; echo $? ) == 0 ]; then
       if [[ -n ${TAGS['lmsquery']} ]]; then
	 echo "INFO: seems ${TAGS['artist_name']} - ${TAGS['title']} already in LMS database. Skipping $URL" >> $WGETLOGFILE
	 do_tag "$( echo ${TAGS['lmsquery']} | grep -iF 'url' | cut -f4 | cut -d/ -f3- | sed -e's/%\([0-9A-F][0-9A-F]\)/\\\\\x\1/g' | xargs echo -e )"
	 continue
      fi
    fi
# wget will run with or w/out additional info
# we need internet and some services to run so again checking for discharging UPS state (see upslog.sh)
[[ -s /tmp/upsstate && $(cat /tmp/upsstate) -lt 7 ]] && break
wget --no-verbose --continue --wait=5 --random-wait --limit-rate=100k -U "$USERAGENT" -a "$WGETLOGFILE" -O /tmp/${FILENAME} $URL
    if [ "$?" == 0 ]; then
        echo "INFO: Download $FILENAME OK." >>$WGETLOGFILE
	#again, if tags collected, renamimg file to meaningful name and calling tagging function
	if [ $DEEZERDEBUG == 1 ] && [[ -v TAGS[@] ]] && [[ -n TAGS['artist_name'] ]] && [[ -n TAGS['title'] ]]; then
	    do_tag "$( readlink -f /tmp/${FILENAME} )"
	    mv "/tmp/${FILENAME}" "${DWNLDIR}/${TAGS['artist_name']} - ${TAGS['title']}.mp3"
	else
	    mv "/tmp/${FILENAME}" ${DWNLDIR}/$(echo $FILENAME|sed -n 's/\.tmp$/\.mp3/p')
	fi
    else
        echo "WARN: There was an error on downloading ${FILENAME}." >>$WGETLOGFILE
    fi
else
    echo "WARN: seems link already expired. Skipping $URL" >> $WGETLOGFILE
fi
done <$DWNLIST
echo "$DWNLIST removing"
rm -f $DWNLIST
}


### MAIN SECTION ###
## Managing download list and collected filelist with links
if [ -e $DWNLIST ]; then
    do_download
fi
if [ -e $FILELOG ]; then
    echo "Temp lazy workaround to avoid running with dwlnd collector script at the same sec."
    sleep 5
##  cat $FILELOG | awk -F"&" '/api/ {print $BASEURL$1}' >$DWNLIST
    mv $FILELOG $DWNLIST
    #echo "$?"
    if [ "$?" == 0 ] &&  [ -e $DWNLIST ]; then
	echo "INFO: DWNLIST created" >>$WGETLOGFILE
	do_download
    fi
fi

exit 0

#for tagging
#if [ $( /bin/bash $SLCLI titles 0 10 tags:a  search:${TAGS['title']} |grep -qF "artist:${TAGS['artist_name']}"; echo $? ) == 0 ]; then
#slcli.sh titles 0 10 tags:au search:Trust | grep -iF 'url' | cut -f4 | cut -d/ -f3- | sed -e's/%\([0-9A-F][0-9A-F]\)/\\\\\x\1/g' | xargs echo -e

#renaming
## ls | awk -F"\%2F" '/\.mp3\?/ {print $4}'
#cd $DWNLDIR
#for i in *=exp=*; do
#    j=`echo $i | awk -F"\%2F" '{print $4".mp3"}'` 
#    mv "$i" "$j"
#done

#wget 
#‘-a logfile’
#‘--append-output=logfile’
#Append to logfile. This is the same as ‘-o’, only it appends to logfile instead of overwriting the old log file. 
#If logfile does not exist, a new file is created. 
#‘-q’
#‘--quiet’
#Turn off Wget’s output.
#‘-nv’
#‘--no-verbose’
#Turn off verbose without being completely quiet (use ‘-q’ for that), 
#which means that error messages and basic information still get printed.
#‘-i file’
#‘--input-file=file’
#Read URLs from a local or external file. If ‘-’ is specified as file, URLs are read from the standard input. 
#(Use ‘./-’ to read from a file literally named ‘-’.) 
#‘-B URL’
#‘--base=URL’
#Resolves relative links using URL as the point of reference, 
#when reading links from an HTML file specified via the ‘-i’/‘--input-file’ option 
#(together with ‘--force-html’, or when the input file was fetched remotely from a server describing it as HTML). 
#This is equivalent to the presence of a BASE tag in the HTML input file, with URL as the value for the href attribute.
#For instance, if you specify ‘http://foo/bar/a.html’ for URL, and Wget reads ‘../baz/b.html’ 
#from the input file, it would be resolved to ‘http://foo/baz/b.html’.
#
#‘-c’
#‘--continue’
#Continue getting a partially-downloaded file. 
#This is useful when you want to finish up a download started by a previous instance of Wget, or by another program. 
#If you use ‘-c’ on a non-empty file, and the server does not support continued downloading, 
#Wget will restart the download from scratch and overwrite the existing file entirely. 
#
#‘-w seconds’
#‘--wait=seconds’
#Wait the specified number of seconds between the retrievals. 
#Use of this option is recommended, as it lightens the server load by making the requests less frequent. 
#Instead of in seconds, the time can be specified in minutes using the m suffix, in hours using h suffix, or in days using d suffix. 
#‘--random-wait’
#Some web sites may perform log analysis to identify retrieval programs such as Wget by looking for statistically 
#significant similarities in the time between requests. 
#This option causes the time between requests to vary between 0.5 and 1.5 * [wait] seconds, 
#where [wait] was specified using the ‘--wait’ option, in order to mask Wget’s presence from such analysis. 
#‘-E’
#‘--adjust-extension’
#If a file of type ‘application/xhtml+xml’ or ‘text/html’ is downloaded and the URL does not end with the regexp ‘\.[Hh][Tt][Mm][Ll]?’, 
#this option will cause the suffix ‘.html’ to be appended to the local filename. 
#This is useful, for instance, when you’re mirroring a remote site that uses ‘.asp’ pages, 
#but you want the mirrored pages to be viewable on your stock Apache server. 
#Another good use for this is when you’re downloading CGI-generated materials. 
#A URL like ‘http://site.com/article.cgi?25’ will be saved as article.cgi?25.html.
#At some point in the future, this option may well be expanded to include suffixes for other types of content, 
#including content types that are not parsed by Wget. 
#‘-U agent-string’
#‘--user-agent=agent-string’
#Specifying empty user agent with ‘--user-agent=""’ instructs Wget not to send the User-Agent header in HTTP requests. 
#‘-P prefix’
#‘--directory-prefix=prefix’
#Set directory prefix to prefix. The directory prefix is the directory where all other files and subdirectories will be saved to, 
#i.e. the top of the retrieval tree. The default is ‘.’ (the current directory). 
#‘--limit-rate=amount’
#Limit the download speed to amount bytes per second. Amount may be expressed in bytes, kilobytes with the ‘k’ suffix, or megabytes with the ‘m’ suffix. For example, ‘--limit-rate=20k’ will limit the retrieval rate to 20KB/s. This is useful when, for whatever reason, you don’t want Wget to consume the entire available bandwidth.
#This option allows the use of decimal numbers, usually in conjunction with power suffixes; for example, ‘--limit-rate=2.5k’ is a legal value. 