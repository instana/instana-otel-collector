module github.com/open-telemetry/opentelemetry-collector-contrib/testbed/mockdatasenders/mockdatadogagentexporter

go 1.23.7

require (
	github.com/DataDog/datadog-agent/pkg/trace/exportable v0.0.0-20201016145401-4646cf596b02
	github.com/tinylib/msgp v1.2.5
	go.opentelemetry.io/collector/component v0.120.1-0.20250224010654-18e18b21da7a
	go.opentelemetry.io/collector/component/componenttest v0.120.1-0.20250224010654-18e18b21da7a
	go.opentelemetry.io/collector/config/confighttp v0.120.1-0.20250224010654-18e18b21da7a
	go.opentelemetry.io/collector/consumer v1.26.1-0.20250224010654-18e18b21da7a
	go.opentelemetry.io/collector/consumer/consumererror v0.120.1-0.20250224010654-18e18b21da7a
	go.opentelemetry.io/collector/exporter v0.120.1-0.20250224010654-18e18b21da7a
	go.opentelemetry.io/collector/pdata v1.26.1-0.20250224010654-18e18b21da7a
)

require (
	github.com/cenkalti/backoff/v4 v4.3.0 // indirect
	github.com/davecgh/go-spew v1.1.1 // indirect
	github.com/felixge/httpsnoop v1.0.4 // indirect
	github.com/fsnotify/fsnotify v1.8.0 // indirect
	github.com/go-logr/logr v1.4.2 // indirect
	github.com/go-logr/stdr v1.2.2 // indirect
	github.com/gogo/protobuf v1.3.2 // indirect
	github.com/golang/snappy v0.0.4 // indirect
	github.com/google/uuid v1.6.0 // indirect
	github.com/hashicorp/go-version v1.7.0 // indirect
	github.com/json-iterator/go v1.1.12 // indirect
	github.com/klauspost/compress v1.17.11 // indirect
	github.com/modern-go/concurrent v0.0.0-20180306012644-bacd9c7ef1dd // indirect
	github.com/modern-go/reflect2 v1.0.2 // indirect
	github.com/philhofer/fwd v1.1.3-0.20240916144458-20a13a1f6b7c // indirect
	github.com/pierrec/lz4/v4 v4.1.22 // indirect
	github.com/pmezard/go-difflib v1.0.0 // indirect
	github.com/rs/cors v1.11.1 // indirect
	github.com/stretchr/testify v1.10.0 // indirect
	go.opentelemetry.io/auto/sdk v1.1.0 // indirect
	go.opentelemetry.io/collector/client v1.26.1-0.20250224010654-18e18b21da7a // indirect
	go.opentelemetry.io/collector/config/configauth v0.120.1-0.20250224010654-18e18b21da7a // indirect
	go.opentelemetry.io/collector/config/configcompression v1.26.1-0.20250224010654-18e18b21da7a // indirect
	go.opentelemetry.io/collector/config/configopaque v1.26.1-0.20250224010654-18e18b21da7a // indirect
	go.opentelemetry.io/collector/config/configretry v1.26.1-0.20250224010654-18e18b21da7a // indirect
	go.opentelemetry.io/collector/config/configtls v1.26.1-0.20250224010654-18e18b21da7a // indirect
	go.opentelemetry.io/collector/extension v0.120.1-0.20250224010654-18e18b21da7a // indirect
	go.opentelemetry.io/collector/extension/auth v0.120.1-0.20250224010654-18e18b21da7a // indirect
	go.opentelemetry.io/collector/extension/xextension v0.120.1-0.20250224010654-18e18b21da7a // indirect
	go.opentelemetry.io/collector/featuregate v1.26.1-0.20250224010654-18e18b21da7a // indirect
	go.opentelemetry.io/collector/pdata/pprofile v0.120.1-0.20250224010654-18e18b21da7a // indirect
	go.opentelemetry.io/collector/pipeline v0.120.1-0.20250224010654-18e18b21da7a // indirect
	go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp v0.59.0 // indirect
	go.opentelemetry.io/otel v1.34.0 // indirect
	go.opentelemetry.io/otel/metric v1.34.0 // indirect
	go.opentelemetry.io/otel/sdk v1.34.0 // indirect
	go.opentelemetry.io/otel/sdk/metric v1.34.0 // indirect
	go.opentelemetry.io/otel/trace v1.34.0 // indirect
	go.uber.org/multierr v1.11.0 // indirect
	go.uber.org/zap v1.27.0 // indirect
	golang.org/x/net v0.38.0 // indirect
	golang.org/x/sys v0.31.0 // indirect
	golang.org/x/text v0.23.0 // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20241202173237-19429a94021a // indirect
	google.golang.org/grpc v1.70.0 // indirect
	google.golang.org/protobuf v1.36.5 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)

retract (
	v0.76.2
	v0.76.1
)
