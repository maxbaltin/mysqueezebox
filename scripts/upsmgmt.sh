#! /bin/bash
PATH=/sbin:/usr/sbin:/bin:/usr/bin
# The pipefail param needed to return real exit code to the upslog.sh script
set -o pipefail
#LOG=/dev/stdout
LOGSCRIPT="$(dirname $0)/upslog.sh"
#LOGSCRIPT usage: 
#--> |xargs /bin/bash $LOGSCRIPT  <-- or 
#--> ($1.. is mandatory to avoid while loop): /bin/bash $LOGSCRIPT "Some message to log"
VCGENCMD=$(which vcgencmd)
SERVICES="squeezeboxserver squeezelite slmon slplay"
#SERVICES="squeezeboxserver squeezelite avahi-daemon gmrender"
#Check "Driver=" field of the 'lsusb -t' output to collect list of devices to stop
### NOTE NOTE NOTE at the moment, name ONLY devices DIRECTLY connected to 4 RPi USB ports,
### NOT THOSE connected to an external hub!
### DO NOT add to the USBDEV var any name connected to external hub, this WILL LEAD to unpredicted results!
### If required,add the WHOLE EXTERNAL USB hub driver name here!!!
USBDEV="cdc_ether ath9k_htc btusb"

### PRE-REQS: 
### mandatory: usbutils
### recommended: vcgencmd (libraspberrypi-bin)
###

function stop_hdmi(){
    if [[ -x $VCGENCMD ]]; then
      $VCGENCMD display_power 0 | xargs /bin/bash $LOGSCRIPT
    else
      /usr/bin/tvservice -o   |xargs /bin/bash $LOGSCRIPT
    fi
}

function start_hdmi(){
    if [[ -x $VCGENCMD ]]; then
     $VCGENCMD display_power 1 | xargs /bin/bash $LOGSCRIPT
    else
     echo "Function not implemented"
     return 1
    fi
}

function stop_music(){
#    /opt/squeezebox/scripts/slfunctions.sh clear_playlist |xargs /bin/bash $LOGSCRIPT
    /opt/squeezebox/scripts/slcli.sh pause  |xargs /bin/bash $LOGSCRIPT
}

function start_music(){
#    /opt/squeezebox/scripts/slfunctions.sh play_random 100 |xargs /bin/bash $LOGSCRIPT
    /opt/squeezebox/scripts/slcli.sh play  |xargs /bin/bash $LOGSCRIPT
}

function stop_services(){
    /bin/bash $LOGSCRIPT "Stopping services"
#    systemctl stop squeezeboxserver squeezelite avahi* gmrender dnsmasq hostapd
    for i; do systemctl stop $i; done
}

function start_services(){
    /bin/bash $LOGSCRIPT "Starting services"
#    systemctl start squeezeboxserver squeezelite avahi* gmrender
    for i; do systemctl start $i; sleep 10; done
}

function stop_cpugov(){
    /bin/bash $LOGSCRIPT "Set low CPU governor"

    echo $(($(grep -e '^arm_freq_min=' /boot/config.txt |cut -d= -f2)*1000)) >/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
    echo "powersave" >/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
}

function start_cpugov(){
    /bin/bash $LOGSCRIPT "Set regular CPU governor"
    echo $(($(grep -e '^arm_freq=' /boot/config.txt |cut -d= -f2)*1000)) >/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
    echo "ondemand"  >/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
#    echo "conservative" >/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
}

function stop_bus(){
# disable the whole USB bus, INCLUDING ETHERNET PORT
    /bin/bash $LOGSCRIPT "Disabling USB bus"
    echo 0 >$(find /sys/devices/ -name $(dmesg -t | grep dwc_otg | grep "DWC OTG Controller" | awk '{print $2}' | cut -d":" -f1))/buspower
}

function start_bus(){
# re-enable the whole USB bus, INCLUDING ETHERNET PORT
    /bin/bash $LOGSCRIPT "Enabling USB bus"
#    echo 1 >$(find /sys/devices/ -name *.usb|head -n1)/buspower
    echo 1 >$(find /sys/devices/ -name $(dmesg -t | grep dwc_otg | grep "DWC OTG Controller" | awk '{print $2}' | cut -d":" -f1))/buspower
#root@DietPi:~# find /sys/devices/ -name *.i2s
#/sys/devices/platform/soc/3f203000.i2s
#root@DietPi:~# find /sys/devices/ -name *.usb
#/sys/devices/platform/soc/3f980000.usb
}

function stop_eth(){
    /bin/bash $LOGSCRIPT "Disabling eth0"
    echo "1-1.1" | tee /sys/bus/usb/drivers/usb/unbind 2>/dev/null 1>/dev/null

    ##WARNING: hub-ctrl causes my RPi2 to unresponsive state sometimes. So I'm not using it here anymore
    ##    /opt/hub-ctrl/hub-ctrl -h 0 -P 1 -p 0
}

function start_eth(){
    /bin/bash $LOGSCRIPT "Enabling eth0"
     echo "1-1.1" | tee /sys/bus/usb/drivers/usb/bind 2>/dev/null 1>/dev/null
# for empty and/or already active ports, error "No such device" is returned;
# this should be parsed and solution or more clever workaround to be applied,
# but at the moment, we just always return Ok status
#true
    ##WARNING: hub-ctrl causes my RPi2 to unresponsive state sometimes. So I'm not using it here anymore
    ##    /opt/hub-ctrl/hub-ctrl -h 0 -P 1 -p 1
}

function stop_usb(){
### NOTE NOTE NOTE at the moment, this works ONLY for devices DIRECTLY connected to 4 RPi USB ports,
### NOT THOSE connected to an external hub!! Or add the WHOLE EXTERNAL USB hub driver name here!!!
    /bin/bash $LOGSCRIPT "Disabling USB ports"
local -A devs=()
while read -r drv port; do 
    devs[$drv]=$port
done < <(lsusb -t | sed -r 's/^.+Port ([[:digit:]]+).+Driver=([^,]+).+/\2 \1/'| uniq | tail -n+3)

for i; do
    [[ ! -z ${devs[$i]} ]] && echo "1-1.${devs[$i]}" | tee /sys/bus/usb/drivers/usb/unbind 2>/dev/null 1>/dev/null
done
    ## another option. WARNING: hub-ctrl causes my RPi2 to unresponsive state sometimes. So I'm not using it here anymore
    ## disable all USB ports (see info below)
    ##    /opt/hub-ctrl/hub-ctrl -h 0 -P 2 -p 0
    ## or disable all USB ports except top port next to the ethernet port (see info below)
    ##    /opt/hub-ctrl/hub-ctrl -h 0 -P 3 -p 0
    ##    /opt/hub-ctrl/hub-ctrl -h 0 -P 4 -p 0
    ##    /opt/hub-ctrl/hub-ctrl -h 0 -P 5 -p 0
}

function start_usb(){
    /bin/bash $LOGSCRIPT "Enabling USB ports"
    for i; do
     echo "1-1.$i" | tee /sys/bus/usb/drivers/usb/bind 2>/dev/null 1>/dev/null
    done
# for empty and/or already active ports, error "No such device" is returned;
# this should be parsed and solution or more clever workaround to be applied,
# but at the moment, we just always return Ok status
#true
    ## another option. WARNING: hub-ctrl causes my RPi2 to unresponsive state sometimes. So I'm not using it here anymore
    ##    /opt/hub-ctrl/hub-ctrl -h 0 -P 2 -p 1
}

########################################
#On my RPi3 the numbers are :-
#2 - Top USB next to the ethernet port
#3 - Bottom USB next to the ethernet port
#4 - Top USB furthest from the ethernet port
#5 - Bottom USB furthest from the ethernet port.
#Port 1 of the hub is the built-in ethernet port.
#
# lsusb -t sample
#root@DietPi:/opt/squeezebox/scripts# lsusb -t
#/:  Bus 01.Port 1: Dev 1, Class=root_hub, Driver=dwc_otg/1p, 480M
#    |__ Port 1: Dev 2, If 0, Class=Hub, Driver=hub/5p, 480M
#        |__ Port 1: Dev 3, If 0, Class=Vendor Specific Class, Driver=smsc95xx, 480M
#        |__ Port 2: Dev 4, If 0, Class=Wireless, Driver=btusb, 12M
#        |__ Port 2: Dev 4, If 1, Class=Wireless, Driver=btusb, 12M
#        |__ Port 3: Dev 7, If 0, Class=Communications, Driver=cdc_ether, 480M
#        |__ Port 3: Dev 7, If 1, Class=CDC Data, Driver=cdc_ether, 480M
#        |__ Port 3: Dev 7, If 2, Class=Mass Storage, Driver=usb-storage, 480M
#        |__ Port 4: Dev 5, If 0, Class=Vendor Specific Class, Driver=ath9k_htc, 480M
#
##WARNING: hub-ctrl causes my RPi2 to unresponsive state sometimes. So I'm not using it here anymore
# https://raspberrypi.stackexchange.com/questions/49440/power-usb-device-over-raspberry-pi-gpio-pin/49442#49442
#    Just tested this with the Pi 3 [...] The USB port numbering from the picture posted above:
#    Hub:Port -- Controlled port(s) 
#    0:1 -- Controls the Ethernet port
#    0:2 -- Controls all four USB ports (not the Ethernet)
#    0:3 -- Controls USB Port 4
#    0:4 -- Controls USB Port 2
#    0:5 -- Controls USB Port 3
#    As best I can tell, USB Port 1 cannot be controlled individually.
# For the above application, the command you can use is sudo ./hub-ctrl -h 3 -P 1 -p 0
# -h is the hub, -P is the port, and -p is for switching power on (1) or off (0).
# The hub and port values for a device can be found with lsusb.
#
# set CPU governor
#performance  - always use max cpu freq
#powersave    - always use min cpu freq
#ondemand     - change cpu freq depending on cpu load (On rasbian, it just switches min and max)
#conservative - smoothly change cpu freq depending on cpu load
#userspace    - allow user space daemon to control cpufreq
#cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
#cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
#echo "powersave" >/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
#echo "ondemand" >/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
#in config.txt:
# (!!!) This (0!) means 'enable cpu freq scaling'
#force_turbo=0
# Set lowest cpu freq. By default, it's 700.
#arm_freq_min=100
#
# Read GPIO value (GPIO 3 - pin 5, row 3)
# https://www.raspberrypi-spy.co.uk/2012/06/simple-guide-to-the-rpi-gpio-header-and-pins/#prettyPhoto
# NOTE: this MIGHT affect UPS values reading
#init:
#  echo "3" >/sys/class/gpio/export
#in to capture values, out to echo (set) values
#  echo "in" > /sys/class/gpio/gpio3/direction
#for pins 5/6 (GPIO3+ground): open =1, shorten =0
#  while true; do cat /sys/class/gpio/gpio3/value; sleep 1;done
#stop working with pin:
#  echo "3" >/sys/class/gpio/unexport
#
########################################

case "$1" in
    stop_hdmi)	stop_hdmi ;;
    start_hdmi)	start_hdmi ;;
    stop_music)	stop_music ;;
    start_music) start_music ;;
    stop_eth)	stop_eth ;;
    start_eth)	start_eth ;;
    stop_usb)	stop_usb $USBDEV ;;
    start_usb)	start_usb 2 3 4 5 ;;
    stop_bus)	stop_bus ;;
    start_bus)	start_bus ;;
    stop_services)	stop_services $SERVICES    ;;
    start_services)	start_services $SERVICES ;;
    stop_cpugov)	stop_cpugov ;;
    start_cpugov)	start_cpugov ;;
    *)	echo "Usage: $0 {[stop|start]_[services|music|usb|cpugov|hdmi|eth|bus]}" ;;
esac

