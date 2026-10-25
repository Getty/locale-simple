package simple

import (
	"fmt"
	"strconv"
	"strings"
	"unicode/utf8"
)

// sprintf formats with the C-style conversions of the shared spec (§5):
// b c d e u f F o s x X, flags + - 0 space '<char>, width, .precision, the
// N$ position and %%. A placeholder without a matching argument stays in the
// output unchanged; surplus arguments are ignored.
func sprintf(format string, args []any) string {
	if !strings.Contains(format, "%") {
		return format
	}
	var out strings.Builder
	next := 0
	for i := 0; i < len(format); {
		c := format[i]
		if c != '%' {
			out.WriteByte(c)
			i++
			continue
		}
		spec, size, ok := parseSpec(format[i:])
		if !ok {
			out.WriteByte('%')
			i++
			continue
		}
		i += size
		if spec.verb == '%' {
			out.WriteByte('%')
			continue
		}
		idx := next
		if spec.pos > 0 {
			idx = spec.pos - 1
		} else {
			next++
		}
		if idx >= len(args) {
			out.WriteString(spec.raw)
			continue
		}
		out.WriteString(spec.render(args[idx]))
	}
	return out.String()
}

type spec struct {
	raw       string
	pos       int
	plus      bool
	left      bool
	zero      bool
	space     bool
	pad       rune
	width     int
	precision int // -1: none
	verb      byte
}

// parseSpec reads one conversion at the start of s (which begins with '%').
func parseSpec(s string) (sp spec, size int, ok bool) {
	sp = spec{pad: ' ', precision: -1}
	i := 1
	if i < len(s) && s[i] == '%' {
		return spec{verb: '%'}, 2, true
	}
	// optional position: digits followed by '$'
	j := i
	for j < len(s) && s[j] >= '0' && s[j] <= '9' {
		j++
	}
	if j > i && j < len(s) && s[j] == '$' {
		sp.pos, _ = strconv.Atoi(s[i:j])
		i = j + 1
	}
flags:
	for i < len(s) {
		switch s[i] {
		case '+':
			sp.plus = true
		case '-':
			sp.left = true
		case '0':
			sp.zero = true
		case ' ':
			sp.space = true
		case '\'':
			if i+1 >= len(s) {
				return sp, 0, false
			}
			r, w := utf8.DecodeRuneInString(s[i+1:])
			sp.pad = r
			i += w
		default:
			break flags
		}
		i++
	}
	j = i
	for j < len(s) && s[j] >= '0' && s[j] <= '9' {
		j++
	}
	if j > i {
		sp.width, _ = strconv.Atoi(s[i:j])
		i = j
	}
	if i < len(s) && s[i] == '.' {
		j = i + 1
		for j < len(s) && s[j] >= '0' && s[j] <= '9' {
			j++
		}
		sp.precision, _ = strconv.Atoi(s[i+1 : j])
		i = j
	}
	if i >= len(s) || strings.IndexByte("bcdeufFosxX", s[i]) < 0 {
		return sp, 0, false
	}
	sp.verb = s[i]
	sp.raw = s[:i+1]
	return sp, i + 1, true
}

func (sp spec) render(arg any) string {
	var body string
	sign := ""
	numeric := true
	switch sp.verb {
	case 's':
		numeric = false
		body = fmt.Sprint(arg)
		if sp.precision >= 0 && utf8.RuneCountInString(body) > sp.precision {
			body = string([]rune(body)[:sp.precision])
		}
	case 'c':
		numeric = false
		body = string(rune(toInt(arg)))
	case 'd':
		v := toInt(arg)
		if v < 0 {
			sign = "-"
			body = strconv.FormatUint(uint64(-v), 10)
		} else {
			sign = sp.plusSign()
			body = strconv.FormatInt(v, 10)
		}
	case 'u':
		body = strconv.FormatUint(uint64(toInt(arg)), 10)
	case 'b':
		body = strconv.FormatUint(uint64(toInt(arg)), 2)
	case 'o':
		body = strconv.FormatUint(uint64(toInt(arg)), 8)
	case 'x':
		body = strconv.FormatUint(uint64(toInt(arg)), 16)
	case 'X':
		body = strings.ToUpper(strconv.FormatUint(uint64(toInt(arg)), 16))
	case 'e', 'f', 'F':
		v := toFloat(arg)
		prec := sp.precision
		if prec < 0 {
			prec = 6
		}
		verb := sp.verb
		if verb == 'F' {
			verb = 'f'
		}
		body = strconv.FormatFloat(v, verb, prec, 64)
		if strings.HasPrefix(body, "-") {
			sign, body = "-", body[1:]
		} else {
			sign = sp.plusSign()
		}
	}
	return sp.justify(sign, body, numeric)
}

func (sp spec) plusSign() string {
	switch {
	case sp.plus:
		return "+"
	case sp.space:
		return " "
	}
	return ""
}

func (sp spec) justify(sign, body string, numeric bool) string {
	fill := sp.width - utf8.RuneCountInString(sign) - utf8.RuneCountInString(body)
	if fill <= 0 {
		return sign + body
	}
	switch {
	case sp.left:
		return sign + body + strings.Repeat(string(sp.pad), fill)
	case sp.zero && numeric && sp.pad == ' ':
		return sign + strings.Repeat("0", fill) + body
	}
	return strings.Repeat(string(sp.pad), fill) + sign + body
}

func toInt(arg any) int64 {
	switch v := arg.(type) {
	case int:
		return int64(v)
	case int8:
		return int64(v)
	case int16:
		return int64(v)
	case int32:
		return int64(v)
	case int64:
		return v
	case uint:
		return int64(v)
	case uint8:
		return int64(v)
	case uint16:
		return int64(v)
	case uint32:
		return int64(v)
	case uint64:
		return int64(v)
	case float32:
		return int64(v)
	case float64:
		return int64(v)
	case bool:
		if v {
			return 1
		}
		return 0
	}
	s := strings.TrimSpace(fmt.Sprint(arg))
	if i, err := strconv.ParseInt(s, 10, 64); err == nil {
		return i
	}
	if f, err := strconv.ParseFloat(s, 64); err == nil {
		return int64(f)
	}
	return 0
}

func toFloat(arg any) float64 {
	switch v := arg.(type) {
	case float64:
		return v
	case float32:
		return float64(v)
	}
	if f, err := strconv.ParseFloat(strings.TrimSpace(fmt.Sprint(arg)), 64); err == nil {
		return f
	}
	return float64(toInt(arg))
}
