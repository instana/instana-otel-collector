# Shell Receiver

The Shell Receiver is an OpenTelemetry Collector component that executes shell commands and collects their output as metrics and/or logs. This receiver is useful for integrating command-line tools and scripts into your observability pipeline.

## 🔒 Security Features (NEW)

**Command Validation is now ENABLED by default!** The receiver validates all commands and blocks dangerous operations that could modify your system:

- ✅ **Allowed**: Read-only commands (`df`, `ps`, `netstat`, `cat`, `grep`, etc.)
- ❌ **Blocked**: Write operations (`rm`, `mkdir`, `chmod`, `echo >`, etc.)
- ❌ **Blocked**: Command chaining (`&&`, `||`, `;`)
- ❌ **Blocked**: Pipes (`|`)
- ❌ **Blocked**: Output redirection (`>`, `>>`)

## ⚠️ Security Warning

**This receiver executes shell commands configured by the user.** While command validation is enabled by default to prevent dangerous operations, you should still:
- Only use in trusted environments
- Regularly audit your command configurations
- Never allow untrusted users to modify the configuration

## Configuration

The receiver supports the following configuration options:

```yaml
receivers:
  shell:
    collection_interval: 60s  # How often to execute commands (default: 60s)
    commands:
      - name: disk_usage       # Required: Unique identifier for this command
        command: df -h /       # Required: Shell command to execute
        shell: /bin/sh         # Optional: Shell to use (default: /bin/sh)
        args: []               # Optional: Additional arguments to pass to the shell
        timeout: 5s            # Optional: Maximum time the command can run
        metric_name: disk.usage # Required for metrics: Name for the metric
        log_name: disk_check   # Optional: Name for log records (defaults to metric_name)
        description: "Check disk usage" # Optional: Human-readable description
        labels:                # Optional: Additional key-value pairs as attributes
          filesystem: "root"
        output_type: both      # Optional: How to process output (metric, log, or both; default: metric)
```

### Command Configuration

Each command in the `commands` list supports the following options:

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| name | string | Yes | | Unique identifier for this command |
| command | string | Yes | | Shell command to execute |
| shell | string | No | /bin/sh | Shell to use for execution |
| args | []string | No | [] | Additional arguments to pass to the shell |
| timeout | duration | No | | Maximum time the command can run |
| metric_name | string | Yes* | | Name to use for the metric. For simple outputs, this is the complete metric name. For tabular outputs, this acts as a metric prefix combined with column names (e.g., "prefix.column_name"). (*required when output_type is "metric" or "both") |
| log_name | string | No | metric_name | Name to use for log records (required when output_type is "log" and metric_name is not set) |
| description | string | No | | Human-readable description of what the command does |
| labels | map[string]string | No | {} | Additional key-value pairs to add as attributes |
| output_type | string | No | "metric" | How to process the command output: "metric", "log", or "both" |
| row_regex | string | No | | Regular expression to match and parse each output row (enables customized parsing) |
| metric_names | []string | No | | Names for each captured field from row_regex (required if row_regex is set) |
| descriptions | []string | No | | Human-readable descriptions for each field (optional, should match metric_names length) |
| field_types | []string | No | | How each field should be processed: "Attribute" or "Gauge" (required if row_regex is set) |

## Output Processing

The receiver supports two parsing modes:

### 1. Automatic Parsing (Default)

When `row_regex` is not specified, the receiver automatically detects the output format:

#### Metrics

When a command's output is processed as a metric (output_type is "metric" or "both"):

- If the output can be parsed as a number, it creates a gauge metric with that value
- If the output is tabular (multiple columns), it creates separate gauge metrics for each numeric column
- If the output cannot be parsed as a number, it creates a sum metric with value 1 and includes the output as an attribute

#### Logs

When a command's output is processed as a log (output_type is "log" or "both"):

- Creates a log record with the command output as the body
- Sets INFO severity by default
- Includes command name, description, and labels as attributes
- If the output can be parsed as a number, adds it as a "value" attribute

### 2. Regex-Based Parsing (Customized)

When `row_regex` is specified, the receiver uses regular expressions to parse the output with full control over field types:

- **row_regex**: Regular expression with capture groups for each field
- **metric_names**: Names for each captured field
- **field_types**: Specifies whether each field is an "Attribute" (string identifier) or "Gauge" (numeric metric)
- **descriptions**: Optional descriptions for each field

This mode provides:
- **Flexibility**: Handle variable and irregular output formats
- **Customization**: Control which fields are attributes vs. metrics
- **Type Safety**: Explicitly define field types (e.g., PID as attribute, not gauge)

## Example Configurations

### Basic Usage

```yaml
receivers:
  shell:
    collection_interval: 30s
    commands:
      - name: cpu_temperature
        command: cat /sys/class/thermal/thermal_zone0/temp
        metric_name: system.cpu.temperature
        description: "CPU temperature in millidegrees Celsius"
```

### Multiple Commands with Different Output Types

```yaml
receivers:
  shell:
    collection_interval: 60s
    commands:
      - name: memory_free
        command: free -m | grep Mem | awk '{print $4}'
        metric_name: system.memory.free
        description: "Free memory in MB"
        labels:
          unit: "MB"
        output_type: metric

      - name: disk_usage
        command: df -h / | grep / | awk '{print $5}' | sed 's/%//'
        metric_name: system.disk.usage
        description: "Root filesystem usage percentage"
        labels:
          filesystem: "root"
          unit: "percent"
        output_type: both

      - name: last_logins
        command: last -n 5
        log_name: system.logins
        description: "Last 5 system logins"
        output_type: log
```

### Automatic Parsing with Multi-Tabular Output

The automatic parsing already handles multi-tabular output effectively:

```yaml
receivers:
  shell:
    collection_interval: 60s
    commands:
      # Automatic parsing - detects tabular format and creates metrics
      - name: system_metrics_auto
        command: hyptop -b -n 1 | awk 'BEGIN {printf "%-12s %-10s %-8s %-12s\n","system","cpucount","cpu%","memoryinGB"}$2 ~ /^[0-9]+$/ {printf "%-12s %-10s %-8s %-12s\n",$1,$2,$3,$5}'
        metric_name: system.metrics.shell.hypervisor
        description: "System CPU and Memory metrics"
        output_type: metric
        # No regex needed - automatically parses tabular output
        # Creates metrics: system.metrics.shell.hypervisor.cpucount, system.metrics.shell.hypervisor.cpu%, etc.
```

### Regex-Based Parsing (Customized Control)

For more control over field types and handling:

```yaml
receivers:
  shell:
    collection_interval: 60s
    commands:
      # Regex-based parsing - explicit control over field types
      - name: system_metrics_regex
        command: hyptop -b -n 1 | awk 'BEGIN {printf "%-12s %-10s %-8s %-12s\n","system","cpucount","cpu%","memoryinGB"}$2 ~ /^[0-9]+$/ {printf "%-12s %-10s %-8s %-12s\n",$1,$2,$3,$5}'
        metric_name: system.metrics.shell.hypervisor
        description: "System CPU and Memory metrics"
        output_type: metric
        row_regex: '^\s*(\S+)\s+(\d+)\s+([\d.]+)\s+([\d.]+)\s*$'
        metric_names:
          - system
          - cpucount
          - cpu
          - memoryinGB
        descriptions:
          - System Name
          - CPU Count
          - CPU Usage Percentage
          - Memory Usage in GB
        field_types:
          - Attribute  # system is an identifier, not a metric
          - Gauge      # cpucount is a numeric metric
          - Gauge      # cpu is a numeric metric
          - Gauge      # memoryinGB is a numeric metric
        labels:
          source: "hyptop"
      
      # Example 2: Process information with PID as attribute
      - name: process_stats
        command: ps aux | grep myapp | awk '{print $2, $3, $4}'
        metric_name: process.metrics
        description: "Process CPU and Memory usage"
        output_type: metric
        row_regex: '^\s*(\d+)\s+([\d.]+)\s+([\d.]+)\s*$'
        metric_names:
          - pid
          - cpu_percent
          - mem_percent
        descriptions:
          - Process ID
          - CPU Usage Percentage
          - Memory Usage Percentage
        field_types:
          - Attribute  # PID is an identifier, not a gauge
          - Gauge      # CPU percentage is a metric
          - Gauge      # Memory percentage is a metric
        labels:
          app: "myapp"
```

### Key Differences

**Automatic Parsing:**
- ✅ Works out of the box for tabular data
- ✅ No regex configuration needed
- ✅ Automatically detects headers and numeric columns
- ⚠️ All numeric fields become gauge metrics
- ⚠️ Cannot distinguish between identifiers (like PID) and actual metrics

**Regex-Based Parsing:**
- ✅ Explicit control over which fields are attributes vs. metrics
- ✅ Prevents identifiers (PID, system names) from being treated as gauges
- ✅ Custom field names and descriptions
- ✅ Handles irregular or variable output formats
- ⚠️ Requires regex pattern configuration

## Benefits of Regex-Based Parsing

1. **Type Control**: Explicitly specify which fields are attributes (identifiers) vs. gauges (metrics)
2. **Flexibility**: Handle complex, irregular, or variable output formats
3. **Field Customization**: Choose exactly which fields to extract and how to name them
4. **Better Semantics**: Prevent identifiers like PID or system names from being treated as numeric metrics
5. **Multiple Rows**: Process multiple rows of data with consistent field extraction
