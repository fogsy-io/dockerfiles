// Forked from https://github.com/janeczku/go-dnsmasq

package server

// Counter is the metric interface used by this package
type Counter interface {
	Inc(i int64)
}

type nopCounter struct{}

func (nopCounter) Inc(_ int64) {}

var (
	StatsForwardCount     Counter = nopCounter{}
	StatsStubForwardCount Counter = nopCounter{}
	StatsLookupCount      Counter = nopCounter{}
	StatsRequestCount     Counter = nopCounter{}
	StatsDnssecOkCount    Counter = nopCounter{}
	StatsNameErrorCount   Counter = nopCounter{}
	StatsNoDataCount      Counter = nopCounter{}

	StatsDnssecCacheMiss Counter = nopCounter{}

	StatsCacheMiss Counter = nopCounter{}
	StatsCacheHit  Counter = nopCounter{}
)
