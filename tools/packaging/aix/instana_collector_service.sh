#!/bin/bash

# Get the absolute path without using readlink -f (not available on AIX)
SCRIPT_PATH=$(cd "$(dirname "$0")/.." && pwd)

SERVICE_NAME="instana-collector"
SERVICE_PATH="$SCRIPT_PATH/bin/instana-otelcol"
SUBSYSTEM_NAME="instanacol"

install_service() {
	# Ensure the script is executable
	chmod +x "$SERVICE_PATH"

	# Create a wrapper script that sources the environment file
	WRAPPER_SCRIPT="$SCRIPT_PATH/bin/instana_collector_wrapper.sh"
	cat > "$WRAPPER_SCRIPT" <<EOF
#!/bin/bash
# Source environment variables
if [ -f "$SCRIPT_PATH/config/config.env" ]; then
    . "$SCRIPT_PATH/config/config.env"
fi
# Start the collector
cd "$SCRIPT_PATH"
exec "$SERVICE_PATH" --config config/config.yaml
EOF
	chmod +x "$WRAPPER_SCRIPT"

	# Check if subsystem already exists
	if lssrc -s "$SUBSYSTEM_NAME" >/dev/null 2>&1; then
		echo "Subsystem $SUBSYSTEM_NAME already exists. Removing it first..."
		rmssys -s "$SUBSYSTEM_NAME"
	fi

	# Create the SRC subsystem
	mkssys -s "$SUBSYSTEM_NAME" \
		-p "$WRAPPER_SCRIPT" -u 0 -S -n 15 -f 9 -R -Q -d \
		-o "$SCRIPT_PATH/logs/collector.out" \
		-e "$SCRIPT_PATH/logs/collector.err"

	# Start the service
	startsrc -s "$SUBSYSTEM_NAME"

	# Check service status
	sleep 2
	lssrc -s "$SUBSYSTEM_NAME"
	
	echo "Service $SERVICE_NAME has been installed and started."
}

uninstall_service() {
	# Stop the service if running
	if lssrc -s "$SUBSYSTEM_NAME" | grep -q active; then
		echo "Stopping service $SERVICE_NAME..."
		stopsrc -s "$SUBSYSTEM_NAME"
		sleep 2
	fi

	# Remove the subsystem
	if lssrc -s "$SUBSYSTEM_NAME" >/dev/null 2>&1; then
		rmssys -s "$SUBSYSTEM_NAME"
		echo "Service $SERVICE_NAME has been uninstalled."
	else
		echo "Service $SERVICE_NAME is not installed."
	fi

	# Remove wrapper script
	rm -f "$SCRIPT_PATH/bin/instana_collector_wrapper.sh"
}

status_service() {
	# Check the status of the service
	if lssrc -s "$SUBSYSTEM_NAME" >/dev/null 2>&1; then
		lssrc -s "$SUBSYSTEM_NAME"
	else
		echo "Service $SERVICE_NAME is not installed."
		exit 1
	fi
}

start_service() {
	# Start the service
	if lssrc -s "$SUBSYSTEM_NAME" | grep -q active; then
		echo "Service $SERVICE_NAME is already running."
	else
		startsrc -s "$SUBSYSTEM_NAME"
		sleep 2
		lssrc -s "$SUBSYSTEM_NAME"
		echo "Service $SERVICE_NAME started."
	fi
}

stop_service() {
	# Stop the service
	if lssrc -s "$SUBSYSTEM_NAME" | grep -q active; then
		stopsrc -s "$SUBSYSTEM_NAME"
		sleep 2
		echo "Service $SERVICE_NAME stopped."
	else
		echo "Service $SERVICE_NAME is not running."
	fi
}

restart_service() {
	# Restart the service
	stop_service
	sleep 1
	start_service
}

case "$1" in
install)
	install_service
	;;
uninstall)
	uninstall_service
	;;
status)
	status_service
	;;
start)
	start_service
	;;
stop)
	stop_service
	;;
restart)
	restart_service
	;;
*)
	echo "Usage: $0 {install|uninstall|status|start|stop|restart}"
	exit 1
	;;
esac

