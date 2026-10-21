# s390 Receiver

The s390 receiver collects metrics from LPAR running on top of PRISM of IBM Z (s390x) systems via the s390_hypfs filesystem. It reads DIAG 204 diagnostic data to collect LPAR (Logical Partition) CPU utilization and capacity group metrics.

## Configuration

The following settings are required:

- `collection_interval`: The interval at which to collect metrics (default: 60s; values below 30s, or unset/zero values, are automatically treated as 30s)
- `hypfs_dir`: The path to the s390_hypfs filesystem (default: /sys/kernel/debug/s390_hypfs)

Example:

```yaml
receivers:
  s390:
    collection_interval: 60s
    hypfs_dir: "/sys/kernel/debug/s390_hypfs"
```

## Metrics

The following metrics are collected:

### CPU Utilization Metrics

- `system.cpu.utilization.core`: LPAR core utilization percentage
  - Unit: %
  - Description: Average LPAR core utilization percentage across the LPAR's reported cores

- `system.cpu.utilization.management`: Management percentage
  - Unit: %
  - Description: Average management/accounting time percentage across the LPAR's reported cores

### LPAR Metrics

- `system.lpar.cores`: Number of reported LPAR cores
  - Unit: cores
  - Description: Number of CPU/core blocks reported for the LPAR.

### Capacity Group Metrics

- `system.group.utilization`: Total capacity group utilization percentage
  - Unit: %
  - Description: Total utilization of the entire capacity group, calculated as the sum of all LPARs' core utilization divided by the group capacity. This is a group-level metric (one per capacity group).
  - Attributes:
    - `capacity.group`: Name of the capacity group
    - `group.capacity`: Capacity limit of the group in cores
  - Only present when capacity groups exist

## Requirements

- IBM Z system running Linux on s390x architecture
- s390_hypfs filesystem mounted (typically at `/sys/kernel/debug/s390_hypfs`)
- LPAR where IDOT(s390 Receiver installed) should have "Global performance data control" enabled 
so that it can view data for all LPARs.

## Attributes

The receiver adds the following resource attributes to all emitted metrics:

- `host.arch`: "s390x"
- `os.type`: "linux"
- `host.id`: "hostname of the LPAR"

The following attributes are added at the metric data point level:

**For LPAR metrics:**
- `lpar.name`: Name of the logical partition
- `capacity.group`: Name of the capacity group (if applicable)

**For capacity group metrics:**
- `capacity.group`: Name of the capacity group
- `group.capacity`: Capacity limit of the group in cores

## How It Works

1. **Initial Baseline**: On startup, the receiver reads DIAG 204 data to establish a baseline
2. **Periodic Collection**: At each collection interval, it reads new DIAG 204 data
3. **Delta Calculation**: Computes CPU utilization by comparing current and previous samples
4. **Metric Generation**: Creates OpenTelemetry metrics with proper attributes
5. **Export**: Sends metrics to configured exporters (Instana, Prometheus, etc.)

## Technical Details

### DIAG 204 Data Structure

The receiver parses binary DIAG 204 data with the following structure:
- **DEBUGFS Header** (64 bytes): Contains data size
- **INFO Header** (64 bytes): Contains number of LPARs
- **System Headers** (96 bytes each): LPAR information (name, cores, capacity group)
- **CPU Info** (96 bytes per core): CPU statistics (type, times, capacity)

### CPU Types

- **CP**: General purpose processors
- **IFL**: Integrated Facility for Linux processors
- **UN**: Unknown/other processor types

### Metrics Calculation

- **Core Utilization**: `(current_lp_time - previous_lp_time) / (current_online_time - previous_online_time) * 100`
- **Management Overhead**: `(current_mgm_time - previous_mgm_time) / (current_online_time - previous_online_time) * 100`
- **Group Utilization**: `(sum of all LPARs' core_utilization in group / capacity) * 100`

## Example Output

When running on an IBM Z system with multiple LPARs:

```
LPAR: PROD1
  - system.cpu.utilization.core: 45.23%
  - system.cpu.utilization.management: 2.15%
  - system.lpar.cores: 8

LPAR: TEST1
  - system.cpu.utilization.core: 12.45%
  - system.cpu.utilization.management: 0.85%
  - system.lpar.cores: 4

Capacity Group: GROUP1
  - system.group.utilization: 67.97% (capacity.group="GROUP1", group.capacity=10.5)
```

**Note:** The `system.group.utilization` metric represents the total utilization of all LPARs in the capacity group, calculated as the sum of all LPARs' core utilization divided by the group capacity. The group capacity is included as an attribute on this metric.

## UI Visualization

In observability platforms like Instana, the metrics appear as:

1. **Infrastructure View**: Each LPAR as a monitored host
2. **Dashboards**: Time-series graphs for CPU utilization, capacity usage
3. **Capacity Groups**: Grouped view of LPARs in the same capacity group
4. **Alerts**: Threshold-based alerts on CPU utilization or capacity exhaustion

## Troubleshooting

### Permission Denied

```
Error: failed to open /sys/kernel/debug/s390_hypfs/diag_204: permission denied
```

**Solution**: Ensure the collector process has read permissions for the hypfs filesystem. May require running as root or adding appropriate capabilities.


### No Metrics Generated

If metrics are not appearing, check:
1. Collection interval is configured as expected; values below 30 seconds are automatically treated as 30 seconds
2. Hypfs filesystem is accessible
3. System is running on s390x architecture

## Performance Considerations

- **Collection Interval**: Default 60s is suitable for most use cases. The minimum effective interval is 30s; lower or unset values are automatically normalized to 30s to avoid unnecessary overhead.
- **Memory Usage**: Minimal, stores only previous sample for delta calculation
- **CPU Overhead**: Very low, binary parsing is efficient
- **I/O Impact**: Single file read per collection interval

## License

Apache License 2.0

