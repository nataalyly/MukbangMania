extends RefCounted

class_name Frac

var n: int  # pembilang
var d: int  # penyebut

@warning_ignore("integer_division")

func _init(p_n: int, p_d: int) -> void:
	n = p_n
	d = p_d

func plus(other: Frac) -> Frac:
	return Frac.new(n * other.d + other.n * d, d * other.d)

func equals(other: Frac) -> bool:
	return n * other.d == other.n * d

func simplified() -> Frac:
	var g := _gcd(absi(n), absi(d))
	return Frac.new(n / g, d / g)

static func _gcd(a: int, b: int) -> int:
	while b != 0:
		var t := b
		b = a % b
		a = t
	return a
