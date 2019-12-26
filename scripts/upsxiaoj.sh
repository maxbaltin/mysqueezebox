#! /bin/bash
# https://github.com/linshuqin329/UPS-18650/blob/master/UPS-18650_zh/UPS_18650.py
PATH=/sbin:/usr/sbin:/bin:/usr/bin
SCRIPT=/opt/UPS-18650/UPS-18650_zh/UPS_18650.py
PYTHON=/usr/bin/python
TEMPLOG=/tmp/upsxiaoj.log

/usr/bin/python $SCRIPT

#grep -q  "end of stream" $TEMPLOG
#    if [ "$?" == 0 ]; then
      #awk '/stream_sock/ {print $5}' $TEMPLOG >>$FILELOG
      #awk '/stream_sock.*\/api\// {gsub(/\&/,""); print $5}' $TEMPLOG >>$FILELOG
#    fi

exit 0