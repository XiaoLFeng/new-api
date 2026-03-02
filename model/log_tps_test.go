package model

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestCalcLogTPS(t *testing.T) {
	testCases := []struct {
		name             string
		promptTokens     int
		completionTokens int
		useTimeSeconds   int
		other            map[string]interface{}
		expect           float64
	}{
		{
			name:             "with_frt",
			promptTokens:     100,
			completionTokens: 50,
			useTimeSeconds:   10,
			other:            map[string]interface{}{"frt": 2000.0},
			expect:           18.625,
		},
		{
			name:             "without_frt",
			promptTokens:     100,
			completionTokens: 50,
			useTimeSeconds:   10,
			other:            map[string]interface{}{},
			expect:           14.9,
		},
		{
			name:             "invalid_frt_string",
			promptTokens:     100,
			completionTokens: 50,
			useTimeSeconds:   10,
			other:            map[string]interface{}{"frt": "invalid"},
			expect:           14.9,
		},
		{
			name:             "effective_duration_not_positive",
			promptTokens:     100,
			completionTokens: 50,
			useTimeSeconds:   2,
			other:            map[string]interface{}{"frt": 2000.0},
			expect:           0,
		},
		{
			name:             "total_tokens_not_enough",
			promptTokens:     1,
			completionTokens: 0,
			useTimeSeconds:   10,
			other:            map[string]interface{}{"frt": 300.0},
			expect:           0,
		},
		{
			name:             "round_to_4_decimals",
			promptTokens:     10,
			completionTokens: 4,
			useTimeSeconds:   3,
			other:            map[string]interface{}{"frt": 700.0},
			expect:           5.6522,
		},
	}

	for _, testCase := range testCases {
		t.Run(testCase.name, func(t *testing.T) {
			actual := calcLogTPS(testCase.promptTokens, testCase.completionTokens, testCase.useTimeSeconds, testCase.other)
			require.InDelta(t, testCase.expect, actual, 0.00001)
		})
	}
}
