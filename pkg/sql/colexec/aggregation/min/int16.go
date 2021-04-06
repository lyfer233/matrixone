package min

import (
	"matrixbase/pkg/container/types"
	"matrixbase/pkg/container/vector"
	"matrixbase/pkg/encoding"
	"matrixbase/pkg/sql/colexec/aggregation"
	"matrixbase/pkg/vectorize/min"
	"matrixbase/pkg/vm/mempool"
	"matrixbase/pkg/vm/process"
)

func NewInt16(typ types.Type) *int16Min {
	return &int16Min{typ: typ}
}

func (a *int16Min) Reset() {
	a.v = 0
	a.cnt = 0
}

func (a *int16Min) Type() types.Type {
	return a.typ
}

func (a *int16Min) Dup() aggregation.Aggregation {
	return &int16Min{typ: a.typ}
}

func (a *int16Min) Fill(sels []int64, vec *vector.Vector) error {
	if n := len(sels); n > 0 {
		v := min.Int16MinSels(vec.Col.([]int16), sels)
		if a.cnt == 0 || v < a.v {
			a.v = v
		}
		a.cnt += int64(n - vec.Nsp.FilterCount(sels))
	} else {
		v := min.Int16Min(vec.Col.([]int16))
		a.cnt += int64(vec.Length() - vec.Nsp.Length())
		if a.cnt == 0 || v < a.v {
			a.v = v
		}
	}
	return nil
}

func (a *int16Min) Eval() interface{} {
	if a.cnt == 0 {
		return nil
	}
	return a.v
}

func (a *int16Min) EvalCopy(proc *process.Process) (*vector.Vector, error) {
	data, err := proc.Alloc(2)
	if err != nil {
		return nil, err
	}
	vec := vector.New(a.typ)
	if a.cnt == 0 {
		vec.Nsp.Add(0)
		copy(data[mempool.CountSize:], encoding.EncodeInt16(0))
	} else {
		copy(data[mempool.CountSize:], encoding.EncodeInt16(a.v))
	}
	vec.Data = data
	vec.Col = encoding.DecodeInt16Slice(data[mempool.CountSize : mempool.CountSize+2])
	return vec, nil
}