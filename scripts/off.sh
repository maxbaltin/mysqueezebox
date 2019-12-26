#! /bin/bash
/opt/squeezebox/scripts/upsmgmt.sh stop_services
#/DietPi/dietpi/func/dietpi-logclear 0 >/dev/null
/sbin/poweroff $1
