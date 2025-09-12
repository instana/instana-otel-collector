# Troubleshooting Guide

This document provides solutions for common issues encountered when using the Instana Distribution of OpenTelemetry Collector.

## General Issues

### Connection Problems

- **Issue**: Collector cannot connect to Instana backend
  - **Solution**: Verify your network configuration and ensure that the collector can reach the Instana backend. Check firewall rules, proxy settings, and port configurations. In addition, check that you have the correct Instana key.

### Collector Not Showing Up in Instana UI

- **Issue**: Collector is running but not appearing in the Instana UI
  - **Solution**: The Instana UI's entities page lists components by the `entity.type` resource attribute. If your collector is not visible, verify that the `entity.type` attribute is correctly configured in your configuration file. Ensure the collector is properly connected to the Instana backend and check for any authentication or connectivity issues. Example resource attribute configuration:

  ```yaml
  telemetry:
    resource:
      entity.type: otel-collector
  ```

### Configuration Issues

- **Issue**: Collector fails to start due to configuration errors
  - **Solution**: Validate your configuration file using the `--config-check` flag before starting the collector. Example command `./otelcol --config config.yaml --config-check`

### Service Not Starting

- **Issue**: The collector service doesn't start after installation
  - **Solution**: Check the service logs for errors and verify that the configuration parameters in `config.env` are correct.

### Supervisor-related Issues

- **Issue**: Supervisor service is running but collector keeps restarting
  - **Solution**: Check the supervisor logs for errors and verify that the collector configuration is valid.

- **Issue**: Supervisor service fails to start
  - **Solution**: Verify that the supervisor configuration in `config.env` is correct and check system logs for any errors.


## Linux Issues

### Log Locations for Linux

- **Collector logs**: By default found under `/opt/instana/collector/logs/`

- **Supervisor logs**: By default found under `/opt/instana/collector/bin/`


### Permission Problems

- **Issue**: Collector cannot access system metrics or log files
  - **Solution**: Ensure the collector process has appropriate permissions. You may need to run it with elevated privileges or add it to specific groups.

### Odd Collector Behavior

- **Issue**: Collector logs show abnormal Telemetry data
  - **Solution**: Restart the collector service using `./instana_collector_service.sh restart` in your installation path to clear any potential issues. If the problem persists, check the collector logs for any anomalies.
