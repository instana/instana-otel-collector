package cache // import "github.com/open-telemetry/opentelemetry-collector-contrib/processor/tailsamplingprocessor/cache"

// import "fmt"

// NewCache creates a new Cache instance with given size.
// If size <= 0, returns a no-op cache.
func NewCache[V any](size int) (Cache[V], error) {
	if size <= 0 {
		return NewNopDecisionCache[V](), nil
	}
	return NewLRUDecisionCache[V](size)
}
