package natural

import (
	"matrixbase/pkg/container/batch"
	"matrixbase/pkg/hash"
	"matrixbase/pkg/intmap/fastmap"
)

const (
	UnitLimit = 1024
)

var (
	ZeroBools  []bool
	OneUint64s []uint64
)

type Container struct {
	builded    bool
	diffs      []bool
	matchs     []int64
	hashs      []uint64
	attrs      []string
	sels       [][]int64      // sels
	slots      *fastmap.Map   // hash code -> sels index
	bats       []*batch.Batch // s relation
	probeState struct {
		bat *batch.Batch // output relation
	}
	groups map[uint64][]*hash.BagGroup // hash code -> group list
}

type Argument struct {
	R     string
	S     string
	Attrs []string
	Ctr   Container
}