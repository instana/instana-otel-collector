#!/bin/bash

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")

SERVICE_NAME="instana-collector"
SERVICE_PATH="$SCRIPT_PATH/instana-otelcol"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

install_service() {
    # Ensure the script is executable
    chmod +x "$SERVICE_PATH"

    # Create the systemd service file
    cat <<EOF | sudo tee "$SERVICE_FILE"
[Unit]
Description=Runme Service
After=network.target

[Service]
ExecStart=$SERVICE_PATH --config ../config/config.yaml
Restart=always
User=root
WorkingDirectory=$SCRIPT_PATH

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd, enable and start the service
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
    sudo systemctl start "$SERVICE_NAME"

    # Check service status
    sudo systemctl status "$SERVICE_NAME" --no-pager
}

uninstall_service() {
    # Stop and disable the service
    sudo systemctl stop "$SERVICE_NAME"
    sudo systemctl disable "$SERVICE_NAME"

    # Remove the service file
    sudo rm -f "$SERVICE_FILE"

    # Reload systemd
    sudo systemctl daemon-reload
    echo "Service $SERVICE_NAME has been uninstalled."
}

status_service() {
    # Check the status of the service
    sudo systemctl status "$SERVICE_NAME" --no-pager
}

start_service() {
    # Start the service
    sudo systemctl start "$SERVICE_NAME"
    echo "Service $SERVICE_NAME started."
}

stop_service() {
    # Stop the service
    sudo systemctl stop "$SERVICE_NAME"
    echo "Service $SERVICE_NAME stopped."
}

restart_service() {
    # Restart the service
    sudo systemctl restart "$SERVICE_NAME"
    echo "Service $SERVICE_NAME restarted."
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
