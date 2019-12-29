#! /bin/bash
PATH=/sbin:/usr/sbin:/bin:/usr/bin
#avoiding another instance of cycled scipt
[[ $(/usr/bin/pgrep -a sh | grep -cF $(basename $0)) -gt 2 && -z "$1" ]] && exit 3
#set addons
LOG=/var/log/slscripts/upslog.log
#LOG="$(dirname $0)/testups.csv"
#LOGBAK=/mnt/dietpi-backup/logfile_storage/testups.csv
#LOG=/dev/stdout
STATELOG=/tmp/upsstate
MGMT="$(dirname $0)/upsmgmt.sh"
PWROFFSCRIPT="$(dirname $0)/off.sh"
#set vars
SLEEP=30
AVG_SAMPLE=10
WMA_SAMPLE=7 #when not in cycle, limited (max 10) by tail default,see func
TRENDVAL_SAMPLE=3
FASTWAKEUP=1 #0 to disable
BATT_FULL=90
BATT_CRITICAL=1
ALWAYS_ON="hostapd ac"
AC_CHECK_ENABLED=1
#PAUSE_MUSIC_AT=-1
STOP_MUSIC_AT=-10
STOP_SRV_ST=-20
SLEEP_AT=-30
POWER_OFF=-60
WAKEUP_AT=1
START_SRV_AT=1
RESUME_AT=1

#### DESCRIPTION #####
# # PRE-REQS:
#app install i2cget hostapd
# # INSTALLATION: 
# - install pre-reqs, 
# - adjust paths above, 
# - add "/path/to/upslog.sh &" to /etc/rc.local (and enable rc-local service) 
# - optionally add to crontab, additional instance will not conflict
#
# 0.1 if script ran with args, no cycle - just log and pass args as comment
# 0.2 if script ran w/out args but another instance active, new one is terminated
# 0.3. basically, script is run by rc.local, optionally supported by crontab in case the script is silently dead; see 0.2
# 1. initially, STATE is set to 9 (full on) or read from /tmp file (see 0.3)
# 1.1 in cycle, every $SLEEP int., inital values logged: log_percent, log_hostapd etc
# 1.2 too short SLEEP interval affects average calcs precision
# 1.3 log_avg - simple log_percent average for AVG_SAMPLE; just for reference, not used for calcs
# 1.4 log_wma - weighted moving average, calculated for WMA_SAMPLE interval
# 1.5 to avoid late reaction for AC attached (and disconnected), we keep WMA_SAMPLE as low as possible;
# 1.6 at the same time, to avoid false trends, we check last WMA results in depth of TRENDVAL_SAMPLE in calc_trend func; if majority the same, a TREND set/confirmed.
# 1.7 TREND(val) is always calculated - calc_function - at least for debug/troubleshooting
# 1.7.1 when TREND is changed, TRENDVAL is reset to either -1 or +1 and then continues
# 1.7.2 initially, TRENDVAL is 0
# 1.8 TRENDVAL is then passed to parse_conditions of STOP_* START_* options above - and we get STATE_WANTED
# 1.9 STATE_WANTED passed to make_decision which is to check against ALWAYS_ON conditions (named SENSORS) and special cases of BATT level;
# 1.9.1 BATT_FULL required because TRENDVAL is unreliable when battery is (nearly) full - no action should be taken based on it;
# 1.9.2 BATT_CRITICAL required for the same (unreliable measurement when batt nearly empty) and for sure to power off gracefully;
# 1.9.3 SENSORS array elements must be either 0 (means FALSE) or integer value (means TRUE)
# 1.10 as soon as we confirm STATE (default 9) is to be changed, set_state does it - step-by-step:
# 1.10.1 set_state receives 2 args: $1 for target state and $2 for direction which is either NEGATIVE number or POSITIVE number
# 1.10.2 set_state is called directly from make_decision, which also checks to never pass 0 as $2
# 1.10.3 if FASTWAKEUP not 0, state increasing will be run in one pass, not step-by-step.
#
#
# STATES: 9 - normal op; 7 - music stopped (paused); 5 - services stopped; 3 - usb off; 1 - whole usb bus off; 0 - power off
# To define custom START_/STOP_ options:
# 1. name does not matter; value is required TRENDVAL to match;
# 2. in parse_condtitions, link new option to required STATE (s=), NOTE the comment in the function!
# 3. in set_state, link state value to actual commands to run; use $2 to diff. between moving-up or down commands.


##### FUNCTIONS #####
function parse_condtitions(){
local s=${1:-${STATE}}
# to keep it simple, case selection just returns first match; to avoid collision of equal values,
# pre-order START_ options in desc order, so highest value first (i.e. 9->8->7->5),
# pre-order STOP_(PAUSE_,SLEEP_) options in asc order, so lowest value first (i.e. 1->3->5->7->8)
case ${TRENDVAL} in
	${RESUME_AT} 	 ) s=9 ;;
	${START_SRV_AT}  ) s=7 ;;
	${WAKEUP_AT}	 ) s=5 ;;
	${POWER_OFF}	 ) s=0 ;;
	${SLEEP_AT}	 ) s=3 ;;
	${STOP_SRV_ST}	 ) s=5 ;;
	${STOP_MUSIC_AT} ) s=7 ;;
#	${PAUSE_MUSIC_AT}) s=8 ;;
#	*) s=${STATE} ;;
esac
echo "$s"
}

function set_state(){
# STATES: 9 - normal op; 7 - music stopped (paused); 5 - services stopped; 3 - usb off; 0 - power off
# args: $1 for target state; $2 for direction which is either NEGATIVE number or POSITIVE number (zero 0 should never be passed here)
case $1 in
	9 ) $MGMT start_music ;;
	7 ) [[ $2 -lt 0  ]] && { $MGMT stop_music; }  || { $MGMT start_services; } ;;
	6 ) [[ $2 -lt 0  ]] && { (( TRENDVAL_SAMPLE++ )); } || { (( TRENDVAL_SAMPLE-- )); } ;;
	5 ) [[ $2 -lt 0  ]] && { $MGMT stop_services; } || { $MGMT start_cpugov; $MGMT start_eth; $MGMT start_usb; } ;;
	4 ) [[ $2 -lt 0  ]] && { (( TRENDVAL_SAMPLE++ )); } || { (( TRENDVAL_SAMPLE-- )); } ;;
	3 ) [[ $2 -lt 0  ]] && { $MGMT stop_usb; $MGMT stop_eth; $MGMT stop_cpugov; $MGMT stop_hdmi; } || { $MGMT start_bus; } ;;
	1 ) [[ $2 -lt 0  ]] && { $MGMT stop_bus; } || true ;;
	0 ) ./$0 "Shutdown"; /bin/bash $PWROFFSCRIPT "--poweroff" ;;
	-1 ) ./$0 "Rebooting"; /bin/bash $PWROFFSCRIPT "--reboot" ;;
esac
#[[ $? == "0" ]] && STATE=$1 || ./$0 "Failed to set state $1"
STATE=$1
echo "${STATE}" >$STATELOG
}


function make_decision(){
local c d s=${STATE_WANTED}
## treat special cases
# stay FULL ON while BATT level FULL
    [[ $s -ne 9 && ${LOGWMA[-1]%%.*} -ge $BATT_FULL ]] && { s=9; TRENDVAL=0; }
# honor ALWAYS_ON vars when state degraded, and batt level not critical
    [[ $s -ne 9 ]] && parse_sensors && s=9
#echo "STATE: ${STATE}, wanted: $s"
# honor BATT_CRITICAL level
    [[ ${#LOGWMA[*]} -gt ${WMA_SAMPLE} && ${LOGWMA[-1]%%.*} -le $BATT_CRITICAL && $TRENDVAL -lt 0 ]] && s=0
## -- ##
#echo "STATE: ${STATE}, wanted: $s"
# Now, if state still need to be changed, increase (+$d/+$d) or decrease (-$d/+$d) the STATE
d=$(( $s - ${STATE} ))
if [[ $FASTWAKEUP -ne 0 && $d -gt 2 ]]; then
    while [[ $s -gt ${STATE} ]]; do
     set_state $(( ${STATE} + 1 )) $d
     # limit loop to 10 iteration, to avoid infinite loop if next STATE cannot be set
     (( c++ )) && (( c >= 10 )) && break
    done
elif [[ $d -ne 0 ]]; then
    set_state $(( ${STATE} + $d / ${d/-/} )) $d
fi
}

function parse_sensors(){
#we don't just check through SENSORS array as not all them might be part of ALWAYS_ON var
for i in $ALWAYS_ON; do
    [[ ${SENSORS[$i]} -ne 0 ]] && return #any sensor detected
done
#return false if all sensors are zero
false
}

function calc_trend(){

#x - current $TRENDVAL, shift to rest args (LOGDIFFs sample)
local t x=$1
shift

if [[ ${AC_CHECK_ENABLED} -eq 1 && -n ${SENSORS["ac"]} ]]; then 
    t=${SENSORS["ac"]/0/-1}
else [[ ! -z "$@" ]]
    # calc if the $@ majority equal -1 or +1 (otherwise, t=0)
    #local s=$( echo $@ | sed -n 's/ /\+/gp' )
    #local t= $(( ($s) / $# ))
    t=$(printf "%d\n" $@ | awk '{s+=$1;n++} END{printf("%.0f",s/n)}')
    #'
fi
# if above true, check if this breaks trend ( (negative trend * positive t) < 0, and v.versa; otherwise (*) always positive -> trend cont.)
[[ $t -ne 0 && $(( $t * $x )) -lt 0 ]] && x=$t || (( x+=$t ))
#echo "$t,$x"
echo "$x"
#else echo "0"
#fi
}

function log_ac(){
# on the UPS-18650 board, you need to short pair of contacts on the back next to 10 gpio pins
#/usr/local/bin/gpio readall
#     +-----+-----+---------+------+---+---Pi 2---+---+------+---------+-----+-----+
#     | BCM | wPi |   Name  | Mode | V | Physical | V | Mode | Name    | wPi | BCM |
#     +-----+-----+---------+------+---+----++----+---+------+---------+-----+-----+
#on:  |   4 |   7 | GPIO. 7 |   IN | 1 |  7 || 8  | 0 | IN   | TxD     | 15  | 14  |
#off: |   4 |   7 | GPIO. 7 |   IN | 0 |  7 || 8  | 0 | IN   | TxD     | 15  | 14  |

local value=$(/usr/local/bin/gpio read 7)

[[ ${AC_CHECK_ENABLED} -eq 1 && $? -eq 0 ]] && echo $value || echo ""

}

function log_time(){
    echo $( date +%d.%m.%y\ %H:%M:%S )
#    echo $( date +%s )
}

function log_hostapd() {
#function returns number of clients connected to the wifi access point 
    /usr/sbin/hostapd_cli interface >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
	echo $(/usr/sbin/hostapd_cli all_sta |grep -cF "connected_time")
    else 
	echo "x"
    fi
}

#function log_bluetooth(){
#function is to return number of bluetooth devices nearby (not yet implemented)
#root@DietPi:/var/log# hcitool scan
#Scanning ...
#        00:24:1C:FD:C1:5E       Motorola Roadster 2
#        FC:A6:21:4A:AD:17       Sirin
#
#}


function log_percent(){
    #echo $(( ($( i2cget -y 1 0x36 0x04 )*100 + $( i2cget -y 1 0x36 0x05 )) ))
    printf "%.2f" "$(( $( i2cget -y 1 0x36 0x04 )*100 + $( i2cget -y 1 0x36 0x05 ) ))e-2"
}

function log_avg(){
    if  [[ -z "$1" ]]; then
     #tail -n$(( ${AVG_SAMPLE}-1 )) $LOG | cut -f2 | awk -v s=${CURVALUE} -v n=1 '{s+=$1;n++} END{print s/n}'
     tail -n$(( ${AVG_SAMPLE}-1 )) $LOG | cut -f2 | awk -v s=${CURVALUE} -v n=1 '{s+=$1;n++} END{printf("%.1f",s/n)}'
    else
     #echo "raw data: $@"
     #echo "$@" |tr [:space:] \\n 
     printf "%.2f\n" "$@" | awk '{s+=$1;n++} END{printf("%.1f",s/n)}'
    fi
}

function log_wma(){
    #local n=$( expr ${#LOGPERCENT[*]} \| $(( $(tail $LOG | grep -cF '') + 1 )) )
    local n=$( [[ -n ${LOGPERCENT[*]} ]] && echo ${#LOGPERCENT[*]} || echo $(( $(tail $LOG | grep -cF '') + 1 )) )
    if [[ $n -ge ${WMA_SAMPLE} ]]; then
     if [[ -z "$1" ]]; then
	tail -n$(( ${WMA_SAMPLE}-1 )) $LOG | cut -f2 \
	| awk -v x=${WMA_SAMPLE} -v s=${CURVALUE} -v n=1 'BEGIN{s=s*x} {s+=$1*n;n++} END{printf("%.1f",s*2/x/(x+1))}'
     else
#	echo "$@" |tr [:space:] \\n 
	printf "%.2f\n" "$@" | awk -v x=${WMA_SAMPLE} -v n=1 '{s+=$1*n;n++} END{printf("%.1f",s*2/x/(x+1))}'
     fi
    else
	echo "x"
    fi
}

##### MAIN SECTION #####

# if script runs with a comment
if  [[ ! -z "$1" ]]; then
    CURVALUE=$(log_percent)
    echo "$(log_time)	${CURVALUE}	$(log_avg)	$(log_wma)	$(log_hostapd)	$@" >>$LOG
#    [[ ! -z "$1" ]] && exit 0
    exit 0
fi

# main loop
declare -a LOGPERCENT
declare -a LOGAVG
declare -a LOGWMA
declare -a LOGDIFF
declare -A SENSORS
declare STATE_WANTED
declare TRENDVAL
STATE=$([[ -s $STATELOG ]] && cat $STATELOG || echo 9)
while true
do
    if [[ $(echo ${#LOGPERCENT[@]}) -ge ${AVG_SAMPLE} ]]; then 
      LOGPERCENT=("${LOGPERCENT[@]:1}")
      LOGAVG=("${LOGAVG[@]:1}")
      LOGWMA=("${LOGWMA[@]:1}")
      LOGDIFF=("${LOGDIFF[@]:1}")
    fi
    SENSORS["hostapd"]=$(log_hostapd)
    SENSORS["ac"]=$(log_ac)
    LOGPERCENT[${#LOGPERCENT[*]}]=$(log_percent)
    if [[ ! -z ${LOGPERCENT[-1]} ]]; then 
     LOGAVG[${#LOGAVG[*]}]=$(log_avg ${LOGPERCENT[@]})
     LOGWMA[${#LOGWMA[*]}]=$(log_wma ${LOGPERCENT[@]:(-${WMA_SAMPLE})})
     # if at least 2 WMA results, calc trend by 2 recent as (diff)/abs(diff) -> 1 or 0 or -1; subst. 0 to avoid 0/0 = nan
     if [[ ${#LOGWMA[*]} -gt ${WMA_SAMPLE} || ${AC_CHECK_ENABLED} -eq 1 ]]; then
      LOGDIFF[${#LOGDIFF[*]}]=$(echo ${LOGWMA[@]:(-2)}| awk '{d=m=$2-$1;sub("^-","",m);sub("^0$","1",m);print d/m}')
      TRENDVAL=$(calc_trend ${TRENDVAL-${SENSORS["ac"]}} ${LOGDIFF[@]:(-${TRENDVAL_SAMPLE})})
      STATE_WANTED=$(parse_condtitions ${STATE_WANTED})
      make_decision
     else
      LOGDIFF[${#LOGDIFF[*]}]=0
      TRENDVAL=0
     fi
#    elif ! parse_sensors && [[ -x $(which i2cget) ]]; then 
    # error reading battery level; reboot to resolve the condition;
    # honor ALWAYS_ON vars - keep powered on
#      set_state -1
    fi
    echo "$(log_time)	${LOGPERCENT[-1]}	${LOGAVG[-1]}	${LOGWMA[-1]}	AC:${SENSORS['ac']}	Wifi:${SENSORS['hostapd']} \
	Diff:${LOGDIFF[-1]}	Trend:$TRENDVAL 	Target:$STATE_WANTED 	Res_state:$STATE" >>$LOG
    sleep $SLEEP
#    echo "$(log_time)	${LOGPERCENT[-1]}	${LOGAVG[-1]}	${LOGWMA[-1]}	${SENSORS['hostapd']}	 \
#	${LOGDIFF[-1]}	$TRENDVAL	$STATE_WANTED	$STATE"
#    sleep 20
done

exit 0
