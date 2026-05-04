"""Small fixed-point helpers for the lock-in DSP golden model."""


def clamp(value, min_value, max_value):
    return max(min_value, min(max_value, value))


def clamp_signed(value, bits):
    limit = 1 << (bits - 1)
    return clamp(int(value), -limit, limit - 1)


def clamp_unsigned(value, bits):
    return clamp(int(value), 0, (1 << bits) - 1)


def twos_complement_hex(value, bits):
    """Return a zero-padded two's-complement hex string."""
    mask = (1 << bits) - 1
    width = (bits + 3) // 4
    return f"{value & mask:0{width}X}"


def round_shift(value, shift):
    """Arithmetic right shift with round-to-nearest behavior."""
    if shift <= 0:
        return int(value)

    offset = 1 << (shift - 1)
    if value >= 0:
        return (value + offset) >> shift
    return -((-value + offset) >> shift)

