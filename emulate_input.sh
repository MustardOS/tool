#!/bin/sh

. /opt/muos/script/var/func.sh

PROC_NAME="${PROC_NAME:-muxfrontend}"
PROC_DELAY="${PROC_DELAY:-2}"

EV_DEV="${EV_DEV:-/dev/input/event1}"
KEY_CODE="${KEY_CODE:-BTN_SOUTH}"

INTERVAL="${INTERVAL:-2}"

PROC_WAIT() {
    while :; do
    	pgrep "$PROC_NAME" >/dev/null 2>&1 && break
        TBOX sleep 1
    done
}

SEND_PRESS() {
    printf "\n\tSending '%s' input to '%s'" "$KEY_CODE" "$EV_DEV"

    evemu-event "$EV_DEV" --type EV_KEY --code "$KEY_CODE" --value 1
    evemu-event "$EV_DEV" --type EV_KEY --code "$KEY_CODE" --value 0
}

while :; do
    printf "Waiting for '%s'" "$PROC_NAME"
    PROC_WAIT

    printf "\n\tDetected '%s' sleeping for %ss" "$PROC_NAME" "$PROC_DELAY"
    TBOX sleep "$PROC_DELAY"

    SEND_PRESS
    TBOX sleep "$INTERVAL"
    
    printf "\n\n"
done

