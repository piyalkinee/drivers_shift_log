package diary

import (
	"errors"
	"strings"
	"time"
)

// Money is stored in whole KZT, never floating point.
type Trip struct {
	ID         string    `json:"id"`
	Start      time.Time `json:"start"`
	End        time.Time `json:"end"`
	Amount     int64     `json:"amount"`
	Payment    string    `json:"payment"`
	Commission int64     `json:"commission"`
}
type Summary struct {
	Count      int   `json:"count"`
	Revenue    int64 `json:"revenue"`
	Commission int64 `json:"commission"`
	Net        int64 `json:"net"`
	Cash       int64 `json:"cash"`
	Card       int64 `json:"card"`
}
type Day struct {
	Date     string  `json:"date"`
	Timezone string  `json:"timezone"`
	Summary  Summary `json:"summary"`
	Trips    []Trip  `json:"trips"`
}

var Almaty = time.FixedZone("Asia/Almaty", 5*60*60)
var ErrConflict = errors.New("этот ID уже используется для другой поездки")

const MaxAmount int64 = 1_000_000_000

func (t Trip) Validate() error {
	if strings.TrimSpace(t.ID) == "" || len(t.ID) > 128 {
		return errors.New("id обязателен, максимум 128 байт")
	}
	if t.Start.IsZero() || t.End.IsZero() || !t.End.After(t.Start) {
		return errors.New("окончание должно быть позже начала")
	}
	if t.Amount <= 0 || t.Amount > MaxAmount {
		return errors.New("сумма должна быть от 1 до 1 000 000 000 ₸")
	}
	if t.Commission < 0 || t.Commission > t.Amount {
		return errors.New("комиссия должна быть от 0 до суммы поездки")
	}
	if t.Payment != "cash" && t.Payment != "card" {
		return errors.New("payment должен быть cash или card")
	}
	return nil
}
func same(a, b Trip) bool {
	return a.ID == b.ID && a.Start.Equal(b.Start) && a.End.Equal(b.End) && a.Amount == b.Amount && a.Commission == b.Commission && a.Payment == b.Payment
}
func Summarize(trips []Trip) Summary {
	s := Summary{Count: len(trips)}
	for _, t := range trips {
		s.Revenue += t.Amount
		s.Commission += t.Commission
		if t.Payment == "cash" {
			s.Cash += t.Amount
		} else {
			s.Card += t.Amount
		}
	}
	s.Net = s.Revenue - s.Commission
	return s
}
