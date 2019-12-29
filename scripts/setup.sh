#!/bin/bash
LOGDIR=/var/log/slscripts
USER=dietpi
GID=100

usermod -g $GID $USER

[[ -d $LOGDIR ]] || mkdir -p $LOGDIR
chgrp -hR users $LOGDIR
chmod -R  g+w $LOGDIR