#! /bin/bash
# We have nothing to do in case of deep discharging UPS state (see upslog.sh)
[[ -s /tmp/upsstate && $(cat /tmp/upsstate) -le 5 ]] && exit 3

PATH=/sbin:/usr/sbin:/bin:/usr/bin
LOGFILE=/tmp/squeezelite.log
FILELOG=/tmp/squeezelite.list
OFFSETLOG=/tmp/offset.sq
OFFSETSTART=1
if [ -e $OFFSETLOG ]; then OFFSETSTART=$( cat $OFFSETLOG ); fi
#    echo $OFFSETSTART
ENDOFSTREAM=$(( $( tail -n +$OFFSETSTART $LOGFILE | grep -m1 -n  "end of stream" | awk -F':' '{print $1}' ) + $OFFSETSTART ))
#echo $ENDOFSTREAM
if [ $ENDOFSTREAM -gt $OFFSETSTART ]; then
      sed -n ${OFFSETSTART},${ENDOFSTREAM}p $LOGFILE  \
      | awk '/stream_sock.*\/api\//{sub(/\&/,"",$5);p=$5;next} /^Host: /{gsub(/[^A-z0-9._-]/,"",$2);h=$2}\
	 END{if (h && p) {print "http://"h""p}}' >>$FILELOG
      echo $ENDOFSTREAM > $OFFSETLOG
fi

#TEMPLOG=/tmp/squeezelitelog.tmp
#OFFSETLOG=/tmp/squeezelite.offset
##/usr/bin/logger "Tail $LOGFILE for end of stream message"
#if [ -e $LOGFILE ]; then
#    /usr/sbin/logtail -f$LOGFILE -o$OFFSETLOG >>$TEMPLOG
#    grep -q  "end of stream" $TEMPLOG
#    if [ "$?" == 0 ]; then
#      awk '/stream_sock.*\/api\//{sub(/\&/,"",$5);p=$5;next} /^Host: /{gsub(/[^A-z0-9._-]/,"",$2);h=$2} END{print "http://"h""p}' $TEMPLOG >>$FILELOG
##awk '/stream_sock.*\/api\//{sub(/\&/,"",$5);p=$5;next} /^Host: /{gsub(/[^A-z0-9._-]/,"",$2);h=$2} {if (last ~ "end of stream") {print "http://"h""p}} {last=$0}' /tmp/squeezelite.log
#      echo "***" >$TEMPLOG
#    fi
#else
#    /usr/bin/logger "WARN: $LOGFILE not found" SQUEEZEBOXLOG
#fi

exit 0

## /usr/sbin/logtail -f/var/log/squeezelite.log -o/home/dietpi/squeezelite.offset |grep "end of stream" && echo $?
## awk '/stream_sock/ {print $5}' /var/log/squeezelite.log
#      #awk '/stream_sock/ {print $5}' $TEMPLOG >>$FILELOG
#      #awk '/stream_sock.*\/api\// {gsub(/\&/,""); print $5}' $TEMPLOG >>$FILELOG
## grep -m1 -n  "end of stream" /tmp/squeezelite.log | awk -F':' '{print $1}'
