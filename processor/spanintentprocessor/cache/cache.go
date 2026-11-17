// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

package cache

// NewCache creates a new Cache instance with given size.
// If size <= 0, returns a no-op cache.
func NewCache[V any](size int) (Cache[V], error) {
	if size <= 0 {
		return NewNopDecisionCache[V](), nil
	}
	return NewLRUDecisionCache[V](size)
}
