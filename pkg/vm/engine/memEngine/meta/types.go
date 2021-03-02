package meta

import "matrixbase/pkg/vm/metadata"

type Metadata struct {
	Segs  int64
	Rows  int64
	Name  string
	Attrs []metadata.Attribute
}