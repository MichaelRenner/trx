#!/bin/bash

# trx - audio stream for two way radios
# (C) Michael Renner <dd0ul@darc.de>
# You need: a computer with pulseaudio on the remote side.
# On this side you need: pulseaudio (or at least pacat) and sox - and for your convenience xterm and arecord 
# Version 0.1

# ToDo:
# 2nd mode for "short time transmission" using read -n 1 -t 5
# fix false arecord output
# more checks if binaries are available
# setup routine with config file
# help output



# change this to fit your needs
PULSE_SERVER=192.168.22.84
PULSE_SERVER=10.8.0.84
RATE=8000
CHANNELS=1
# use pacmd list-sources | grep name:" and "pacmd list-sinks | grep name:"  to find out the devices
DEVICE_INPUT=alsa_input.usb-Burr-Brown_from_TI_USB_Audio_CODEC-00-CODEC.analog-stereo
DEVICE_OUTPUT=alsa_output.usb-Burr-Brown_from_TI_USB_Audio_CODEC-00-CODEC.analog-stereo
PACAT=/usr/bin/pacat
PLAY=/usr/bin/play
REC=/usr/bin/rec
STATE=0

if xset q | fgrep -q "Caps Lock:   on" ; then
	echo "please do not start this script with acticated caps lock key"
	exit
fi

# two functions

rx () {
	$(${PACAT} --server=${PULSE_SERVER} --record -d ${DEVICE_INPUT} --rate=${RATE} --channels=${CHANNELS} | ${PLAY} -t raw -r ${RATE} -e signed-integer -L -b 16 -c ${CHANNELS} -S - 2>/dev/null) &
	xterm -sb -rightbar -fg yellow -bg black -e arecord --rate=${RATE} -f cd --vumeter=mono -d 0 -vv /dev/null &
	PID_XTERM=$!
}

tx () {
	$(${REC} -t raw -r ${RATE} -e signed-integer -L -b 16 -c ${CHANNELS} - | ${PACAT} --server=${PULSE_SERVER} --playback -d ${DEVICE_OUTPUT} --rate=${RATE} --channels=${CHANNELS} )&
}

export STATE
while true ; do
	if xset q | fgrep -q "Caps Lock:   off"
	then
    		#echo "Caps-Lock ist aus. STATE ist ${STATE}"
		if [ "${STATE}" == "0" ] ; then
			echo "starting rx"
			rx
			STATE=RECORD
		fi
		if [ "${STATE}" == "PLAYBACK" ] ; then
			#echo "Caps-Lock is off, but STATE is PLAYBACK? This means: Change mode!"
			# first: kill record process
			kill $(ps -eaf | grep ${PACAT} | grep ${PULSE_SERVER} | grep playback | grep -v grep | awk '{ print $2 }')
			# now start the loudspeaker
			echo "starting rx"
			rx
			STATE=RECORD
		fi
	else
    		#echo "Caps-lock ist an. STATE ist ${STATE}"
		if [ "${STATE}" == "RECORD" ] ; then
			#echo "Caps-Lock is on, but STATE is RECORD? This means: Change mode!"
			# first: kill playback process
			#kill $(ps -eaf | grep ${PACAT} | grep ${PULSE_SERVER} | grep record | grep -v grep | awk '{ print $2 }')
			kill $(ps -eaf | grep ${PLAY} | grep ${RATE} | grep -v grep | awk '{ print $2 }')
			kill $PID_XTERM
			# now start the microphone
			echo "starting tx"
			tx
			STATE=PLAYBACK
		fi
	fi
sleep 1
done


#kill $(ps -eaf | grep "/usr/bin/pacat" | grep 192.168.22.84 | grep record | grep -v grep | awk '{ print $2 }')
