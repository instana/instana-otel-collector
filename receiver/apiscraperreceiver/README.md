# API Scraper Receiver

The API Scraper Receiver scrapes metrics from REST APIs on a configurable interval and converts them into OpenTelemetry metrics. It supports multiple authentication methods, dynamic URL templating, multi-step API dependency chains, and both flat and nested JSON response structures including OpenTelemetry wire-format (`resourceMetrics`) responses.

---

## Features

- **Periodic scraping** — configurable collection interval per receiver
- **Four authentication types** — Bearer token, Basic, API Key, Session (login/logout lifecycle)
- **Dynamic URL templating** — `{{variable}}` placeholders resolved from prior API responses
- **API dependency chains** — `depends_on` + `for_each` to fan out calls across extracted values
- **Flexible JSON path navigation** — dot notation + array indexing (`data.items[0].metrics`)
- **Nested metrics extraction** — drill into `scopeMetrics[0].metrics` style arrays per item
- **OTel resource attribute extraction** — label extraction from `resource.attributes` key/value arrays
- **Auto label extraction** — `extract_all_labels` to capture all scalar fields as labels
- **Label cleanup** — `strip_label_prefix` and `exclude_labels` to control label cardinality
- **TLS control** — per-API `insecure_skip_verify` for self-signed certificates
- **Graceful empty responses** — HTTP 204 or empty body skipped without error

---

## Configuration Reference

### Receiver level

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `collection_interval` | duration | `60s` | How often to scrape all configured APIs |
| `apis` | list | required | List of API endpoint definitions |

### API level

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `name` | string | required | Unique identifier for this API endpoint |
| `url` | string | required | HTTP endpoint URL. Supports `{{variable}}` templating |
| `method` | string | `GET` | HTTP method |
| `timeout` | duration | `30s` | Per-request timeout |
| `headers` | map | — | Custom HTTP headers |
| `body` | string | — | Request body for POST/PUT requests |
| `insecure_skip_verify` | bool | `false` | Skip TLS certificate verification (not for production) |
| `auth` | object | — | Authentication configuration (see below) |
| `metric_path` | string | — | JSON path to navigate to the metrics array/object (e.g. `data.metrics`) |
| `metric_name_key` | string | `name` | JSON key whose value becomes the metric name |
| `metric_value_key` | string | `value` | JSON key whose value becomes the metric value |
| `metric_type` | string | `gauge` | Metric type: `gauge` or `sum` |
| `metric_labels` | map | — | Static label key → value pairs attached to every metric |
| `depends_on` | string | — | Name of another API that must run first; its extracted variables are available here |
| `extract_variables` | list | — | Variables to extract from this API's response for use in downstream APIs |
| `for_each` | string | — | Variable name: repeat this API call once per extracted value |
| `extract_nested_metrics` | bool | `false` | Enable nested metrics array extraction within each `metric_path` item |
| `nested_metrics_path` | string | — | JSON path (relative to each item) to the nested metrics array. Supports full path navigation e.g. `scopeMetrics[0].metrics` |
| `nested_metric_name_key` | string | `metric_name_key` | Key for metric name within each nested entry |
| `nested_metric_value_path` | string | `metric_value_key` | Path to metric value within each nested entry (supports dot notation) |
| `extract_all_labels` | bool | `false` | Auto-extract all scalar fields as labels. Also handles OTel `resource.attributes` key/value array format |
| `exclude_labels` | list | — | Label keys to exclude when using `extract_all_labels` |
| `strip_label_prefix` | string | — | Prefix to strip from every label key (e.g. `storage.system.` → `vendor`, `model`) |

### Authentication — `auth`

| Parameter | Type | Description |
|-----------|------|-------------|
| `type` | string | `bearer`, `basic`, `apikey`, or `session` |
| `token` | string | Bearer token value |
| `username` | string | Username for basic or session auth |
| `password` | string | Password for basic or session auth |
| `api_key` | string | API key value. Supports `{{variable}}` templating |
| `header_name` | string | Header name for API key (e.g. `X-API-Key`, `x-api-token`) |
| `session` | object | Session auth config (see below) |

### Session authentication — `auth.session`

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `login_url` | string | required | Endpoint to POST credentials to |
| `login_method` | string | `POST` | HTTP method for login request |
| `login_body` | string | required | Request body template. Supports `{{username}}` and `{{password}}` |
| `login_headers` | map | — | Extra headers for the login request |
| `session_token_path` | string | required | JSON or XML path to the session token in the login response |
| `session_header_name` | string | required | Header name to send the session token on subsequent requests |
| `session_token_prefix` | string | `""` | Optional prefix e.g. `Bearer ` |
| `logout_url` | string | — | Endpoint to DELETE/POST on collector shutdown |
| `logout_method` | string | `DELETE` | HTTP method for logout |
| `response_format` | string | `json` | Login response format: `json` or `xml` |

### Variable extraction — `extract_variables[]`

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | string | Variable name referenced as `{{name}}` in downstream APIs |
| `path` | string | JSON path to extract. Use `[*]` for array extraction e.g. `items[*].id` |
| `transform` | string | Optional regex to transform each value e.g. `regex:/api/items/(.*)` |
| `filter_path` | string | JSON path to a boolean/string field used to filter items |
| `filter_value` | string | Expected value for the filter (default: `true`) |

---

## Examples

### 1. Simple public API

```yaml
receivers:
  apiscraper:
    collection_interval: 60s
    apis:
      - name: "users"
        url: "https://jsonplaceholder.typicode.com/users"
        method: "GET"
        timeout: 10s
        metric_name_key: "username"
        metric_value_key: "id"
        metric_type: "gauge"
        extract_all_labels: true
        exclude_labels:
          - "address"
          - "company"
        metric_labels:
          source: "jsonplaceholder"

service:
  pipelines:
    metrics/users:
      receivers: [apiscraper]
      exporters: [debug]
```

**Response shape:**
```json
[
  {"id": 1, "name": "Leanne Graham", "username": "Bret", "email": "Sincere@april.biz", ...},
  {"id": 2, "name": "Ervin Howell",  "username": "Antonette", ...}
]
```

**Result:** one `gauge` data point per user with `username` as metric name, `id` as value, and `name`, `email`, `phone`, `website` as labels.

---

### 2. Bearer token auth with nested path

```yaml
receivers:
  apiscraper:
    collection_interval: 30s
    apis:
      - name: "app_metrics"
        url: "https://api.example.com/stats"
        method: "GET"
        auth:
          type: "bearer"
          token: "${env:API_TOKEN}"
        metric_path: "data.metrics"
        metric_name_key: "metric_name"
        metric_value_key: "metric_value"
        metric_type: "gauge"
        metric_labels:
          source: "app"
```

**Response shape:**
```json
{"data": {"metrics": [{"metric_name": "requests", "metric_value": 1500}]}}
```

---

### 3. API Key authentication

```yaml
receivers:
  apiscraper:
    collection_interval: 60s
    apis:
      - name: "service_health"
        url: "https://api.example.com/health"
        method: "GET"
        auth:
          type: "apikey"
          api_key: "${env:API_KEY}"
          header_name: "X-API-Key"
        metric_name_key: "component"
        metric_value_key: "uptime_seconds"
        metric_type: "gauge"
```

---

### 4. Two-step token auth → metrics (depends_on)

This is the pattern used for IBM Storage Insights and similar APIs that issue a token via one endpoint and use it in all subsequent calls.

```yaml
receivers:
  apiscraper:
    collection_interval: 120s
    apis:
      # Step 1 — get token
      - name: "get_token"
        url: "https://api.example.com/token"
        method: "POST"
        headers:
          x-api-key: "${env:API_KEY}"
        extract_variables:
          - name: "auth_token"
            path: "resourceMetrics[0].resource.attributes[0].value.stringValue"
        metric_path: ""
        metric_name_key: "status"
        metric_value_key: "status"
        metric_type: "gauge"

      # Step 2 — use token
      - name: "get_metrics"
        url: "https://api.example.com/storage-systems/{{system_id}}"
        method: "GET"
        depends_on: "get_token"
        auth:
          type: "apikey"
          api_key: "{{auth_token}}"
          header_name: "x-api-token"
        metric_path: "resourceMetrics"
        extract_nested_metrics: true
        nested_metrics_path: "scopeMetrics[0].metrics"
        nested_metric_name_key: "name"
        nested_metric_value_path: "gauge.dataPoints[0].asInt"
        metric_type: "gauge"
        extract_all_labels: true
        strip_label_prefix: "storage.system."
        exclude_labels:
          - "storage.system.url"
          - "storage.system.tenant_id"
        metric_labels:
          source: "storage_insights"
```

**Response shape (OTel resourceMetrics format):**
```json
{
  "resourceMetrics": [{
    "resource": {
      "attributes": [
        {"key": "storage.system.vendor",  "value": {"stringValue": "IBM"}},
        {"key": "storage.system.model",   "value": {"stringValue": "FlashSystem"}},
        {"key": "storage.system.condition","value": {"stringValue": "normal"}}
      ]
    },
    "scopeMetrics": [{
      "metrics": [
        {"name": "storage.system.raw_capacity_bytes",
         "gauge": {"dataPoints": [{"asInt": 92152818302976}]}}
      ]
    }]
  }]
}
```

**Result:** metric `storage.system.raw_capacity_bytes` with value `92152818302976` and labels `vendor=IBM`, `model=FlashSystem`, `condition=normal` (prefix `storage.system.` stripped).

---

### 5. for_each — fan-out across multiple resources

```yaml
receivers:
  apiscraper:
    collection_interval: 60s
    apis:
      # Step 1 — list resources, extract their IDs
      - name: "list_resources"
        url: "https://api.example.com/api/resources"
        method: "GET"
        auth:
          type: "session"
          username: "${env:USERNAME}"
          password: "${env:PASSWORD}"
          session:
            login_url: "https://api.example.com/api/sessions"
            login_method: "POST"
            login_body: '{"userid":"{{username}}","password":"{{password}}"}'
            login_headers:
              Content-Type: "application/json"
            session_token_path: "api-session"
            session_header_name: "X-API-Session"
            logout_url: "https://api.example.com/api/sessions/this-session"
            logout_method: "DELETE"
        extract_variables:
          - name: "resource_id"
            path: "resources[*].object-uri"
            transform: "regex:/api/resources/(.*)"
        metric_name_key: "name"
        metric_value_key: "status"
        metric_type: "gauge"

      # Step 2 — called ONCE PER resource_id
      - name: "resource_metrics"
        depends_on: "list_resources"
        for_each: "resource_id"
        url: "https://api.example.com/api/resources/{{resource_id}}/metrics"
        method: "GET"
        auth:
          type: "session"
        metric_path: "metrics"
        metric_name_key: "metric-name"
        metric_value_key: "metric-value"
        metric_type: "gauge"
        metric_labels:
          resource_id: "{{resource_id}}"
```

---

### 6. Session authentication (JSON login)

```yaml
receivers:
  apiscraper:
    collection_interval: 30s
    apis:
      - name: "secured_api"
        url: "https://api.example.com/v1/metrics"
        method: "GET"
        auth:
          type: "session"
          username: "${env:API_USER}"
          password: "${env:API_PASS}"
          session:
            login_url: "https://api.example.com/v1/auth/login"
            login_method: "POST"
            login_body: '{"username":"{{username}}","password":"{{password}}"}'
            login_headers:
              Content-Type: "application/json"
            session_token_path: "data.token"
            session_header_name: "Authorization"
            session_token_prefix: "Bearer "
            logout_url: "https://api.example.com/v1/auth/logout"
            logout_method: "POST"
        metric_name_key: "name"
        metric_value_key: "value"
        metric_type: "gauge"
```

**Login response:**
```json
{"status": "success", "data": {"token": "eyJhbGci..."}}
```

**Subsequent API request header:**
```
Authorization: Bearer eyJhbGci...
```

---

### 7. Session authentication (XML login — Power HMC style)

```yaml
        auth:
          type: "session"
          username: "${env:HMC_USERNAME}"
          password: "${env:HMC_PASSWORD}"
          session:
            login_url: "https://hmc-host:12443/rest/api/web/Logon"
            login_method: "PUT"
            login_body: |
              <?xml version="1.0" encoding="UTF-8"?>
              <LogonRequest xmlns="http://www.ibm.com/xmlns/systems/power/firmware/web/mc/2012_10/">
                <UserID>{{username}}</UserID>
                <Password>{{password}}</Password>
              </LogonRequest>
            login_headers:
              Content-Type: "application/vnd.ibm.powervm.web+xml; type=LogonRequest"
            session_token_path: "X-API-Session"
            session_header_name: "X-API-Session"
            logout_url: "https://hmc-host:12443/rest/api/web/Logon"
            logout_method: "DELETE"
            response_format: "xml"
```

---

## JSON path navigation

The receiver supports dot notation and array index access in all `*_path` fields.

| Pattern | Example | Description |
|---------|---------|-------------|
| Simple key | `data` | Top-level key |
| Nested keys | `data.metrics` | Dot-separated traversal |
| Array index | `data.items[0]` | Access specific element |
| Index in middle | `servers[1].metrics` | Index then continue |
| Deep path | `a[0].b[1].c` | Multiple indices |

### Variable extraction wildcard

For `extract_variables`, use `[*]` to collect a value from every element of an array:

```yaml
extract_variables:
  - name: "system_id"
    path: "systems[*].id"               # collects all ids
  - name: "active_id"
    path: "systems[*].id"
    filter_path: "active"               # only where active == true
    filter_value: "true"
  - name: "cpc_id"
    path: "cpcs[*].object-uri"
    transform: "regex:/api/cpcs/(.*)"   # extract ID from URI path
```

---

## Complete pipeline example

```yaml
receivers:
  apiscraper:
    collection_interval: 60s
    apis:
      - name: "my_api"
        url: "https://api.example.com/metrics"
        method: "GET"
        auth:
          type: "bearer"
          token: "${env:API_TOKEN}"
        metric_name_key: "name"
        metric_value_key: "value"
        metric_type: "gauge"
        metric_labels:
          environment: "production"

processors:
  batch:
    timeout: 10s

exporters:
  debug:
    verbosity: detailed
  otlp/instana:
    endpoint: "${env:INSTANA_OTEL_ENDPOINT_GRPC}"
    headers:
      x-instana-key: "${env:INSTANA_KEY}"
      x-instana-host: "${env:HOSTNAME}"

service:
  pipelines:
    metrics/api:
      receivers: [apiscraper]
      processors: [batch]
      exporters: [debug, otlp/instana]
```

---

## Supported value types

The receiver converts API response values to `float64` for all metric types:

| JSON type | Conversion |
|-----------|-----------|
| `number` (float) | Used directly |
| `integer` | Cast to float64 |
| `boolean` | `true` → `1.0`, `false` → `0.0` |
| `string` (numeric) | Parsed as float64 |
| `string` (non-numeric) | `1.0` (presence metric) |

---

## Troubleshooting

### Enable debug logging

```yaml
service:
  telemetry:
    logs:
      level: debug
```

### Common issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| `unknown type: "apiscraper"` | Receiver not registered in binary | Rebuild with `apiscraperreceiver` in `components.go` |
| `Metric value key not found` | `metric_value_key` does not exist in response object | Check actual JSON response keys; update config |
| Labels not extracted from OTel response | Response uses `resource.attributes` array format | Use `extract_all_labels: true`; current scraper handles OTel wire format automatically |
| Session token expired mid-run | Token TTL shorter than `collection_interval` | Reduce `collection_interval` or implement token refresh logic |
| TLS handshake error with self-signed cert | Certificate validation failure | Set `insecure_skip_verify: true` per API (not for production) |
