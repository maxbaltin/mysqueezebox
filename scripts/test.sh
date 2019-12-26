#! /bin/bash
#STATE="77"
echo "@: $@"
echo "#: $#"
USBDEV="cdc_ether ath9k_htc btusb"
#lsusb -t | sed -r 's/^.+Port ([[:digit:]]+).+Driver=([^,]+).+/\2 \1/'
#declare -A TAGS=()
#while read -r name val; do TAGS[$name]=$val; done < <(lsusb -t | sed -r 's/^.+Port ([[:digit:]]+).+Driver=([^,]+).+/\2 \1/')
#'
#declare -p TAGS
#echo ${#TAGS[*]}
#echo ${!TAGS[*]}
#echo ${TAGS[*]}
function stop_usb(){
local -A TAGS=();
while read -r name val;do 
    TAGS[$name]=$val; done < <(lsusb -t | sed -r 's/^.+Port ([[:digit:]]+).+Driver=([^,]+).+/\2 \1/')
for i; do echo "1-1.${TAGS[$i]}"; done
}
stop_usb $USBDEV
#echo ${@:2}
#echo "if $2 null: ${2:-${STATE}}"
#sum=$( echo $@ | sed -n 's/ /\+/gp' )
#echo $(( ($sum) / $# ))
#echo "==="
#printf "%d=\n" "$@"
#echo "==="
#printf "%d\n" "$@" | awk '{s+=$1;n++} END{printf("%.1f\n",s/n)}'
#temp=$(printf "%.0f" $(printf "%d\n" "$@" | awk '{s+=$1;n++} END{printf("%.1f",s/n)}'))
#echo $temp
#for e;do echo "$e: $(( $e / ${e/-/} ))"; done
#MGMT="timeout 5 /opt/squeezebox/scripts/upsmgmt.sh"
#$MGMT start_music
#/opt/squeezebox/scripts/slcli.sh play | xargs echo -e
#[[ $1 == 1 ]] && echo "\$1 is 1" || { echo "\$1 not 1"; echo "second arg"; }
#echo $(dirname $0)
#MGMT="$(dirname $0)/upsmgmt.sh"
#echo $MGMT
#$MGMT
