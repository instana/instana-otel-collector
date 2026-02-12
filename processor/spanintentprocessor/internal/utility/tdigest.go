// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

package utility // import "github.com/open-telemetry/opentelemetry-collector-contrib/processor/spanintentprocessor/internal/utility"

import (
	"math"
	"sort"
)

type centroid struct {
	mean  float64
	count float64
}

type TDigest struct {
	compression float64
	centroids   []centroid
	count       float64
}

func NewTDigest(compression ...float64) *TDigest {
	// Setting default compression to allow for no arguments
	c := 100.0
	if len(compression) > 0 {
		c = compression[0]
	}

	return &TDigest{
		compression: c,
		centroids:   []centroid{},
		count:       0,
	}
}

func (t *TDigest) Count() float64 {
	return t.count
}

func (t *TDigest) Add(value, w float64) {
	inserted := false
	for i := range t.centroids {
		c := &t.centroids[i]
		if math.Abs(c.mean-value) <= 1.0 {
			c.mean = (c.mean*c.count + value*w) / (c.count + w)
			c.count += w
			inserted = true
			break
		}
	}
	if !inserted {
		t.centroids = append(t.centroids, centroid{mean: value, count: w})
	}
	t.count += w

	if len(t.centroids) > 100 {
		t.compress()
	}
}

func (t *TDigest) compress() {
	sort.Slice(t.centroids, func(i, j int) bool {
		return t.centroids[i].mean < t.centroids[j].mean
	})

	newCentroids := []centroid{}
	var cur centroid

	for i, c := range t.centroids {
		if i == 0 {
			cur = c
			continue
		}
		if math.Abs(cur.mean-c.mean) <= 1.0 {
			total := cur.count + c.count
			cur.mean = (cur.mean*cur.count + c.mean*c.count) / total
			cur.count = total
		} else {
			newCentroids = append(newCentroids, cur)
			cur = c
		}
	}
	newCentroids = append(newCentroids, cur)
	t.centroids = newCentroids
}

func (t *TDigest) Quantile(q float64) float64 {
	if len(t.centroids) == 0 {
		return 0
	}
	sort.Slice(t.centroids, func(i, j int) bool {
		return t.centroids[i].mean < t.centroids[j].mean
	})

	target := q * t.count
	var sum float64

	for _, c := range t.centroids {
		sum += c.count
		if sum >= target {
			return c.mean
		}
	}
	return t.centroids[len(t.centroids)-1].mean
}
