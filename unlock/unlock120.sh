#!/bin/bash
# Claude script:
# This script wil run the unlock120.run script with OpenOCD, and will automatically retry until it succeeds.
# The script will stop the OpenOCD process once the unlock is successful, and will print the number of attempts it took to succeed.

set -u

CFG="./raspyh.cfg"
RUN="unlock120.run"
LOGFILE="$(mktemp /tmp/unlock120.XXXXXX.log)"
ATTEMPT=0


SUCCESS_PATTERN="stm32h7x unlocked"


ERROR_PATTERN="Error:"

cleanup() {
	rm -f "$LOGFILE"
}
trap cleanup EXIT

echo "=== unlock120 ==="
echo "Config : $CFG"
echo "Script : $RUN"
echo "Log    : $LOGFILE"
echo "================="
echo

while true; do
	ATTEMPT=$((ATTEMPT + 1))
	echo ">>> Poging $ATTEMPT..."
	: > "$LOGFILE"


	stdbuf -oL -eL openocd -f "$CFG" -f "$RUN" > "$LOGFILE" 2>&1 &
	OPENOCD_PID=$!


	tail -n +1 -f "$LOGFILE" --pid="$OPENOCD_PID" 2>/dev/null &
	TAIL_PID=$!

	FOUND_SUCCESS=0
	while kill -0 "$OPENOCD_PID" 2>/dev/null; do
		if grep -q "$SUCCESS_PATTERN" "$LOGFILE" 2>/dev/null; then
			FOUND_SUCCESS=1
			break
		fi
		sleep 0.2
	done

	if [ "$FOUND_SUCCESS" -eq 1 ]; then

		sleep 0.3
		kill "$OPENOCD_PID" 2>/dev/null
		wait "$OPENOCD_PID" 2>/dev/null
	else

		wait "$OPENOCD_PID" 2>/dev/null
	fi

	sleep 0.2
	kill "$TAIL_PID" 2>/dev/null
	wait "$TAIL_PID" 2>/dev/null

	if grep -q "$SUCCESS_PATTERN" "$LOGFILE"; then
		echo
		echo ">>> Unlock succesfull after $ATTEMPT attempt(s)."
		exit 0
	fi

	if grep -q "$ERROR_PATTERN" "$LOGFILE"; then
		echo
		echo "!!! Error message(s) in attempt $ATTEMPT:"
		grep "$ERROR_PATTERN" "$LOGFILE" | sed 's/^/    /'
		echo
	fi

	echo ">>> Trying again..."
	sleep 0.5
done