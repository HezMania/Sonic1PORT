#!/usr/bin/env python3
"""Phase 87: import retail Sonic 2 EHZ music/DAC + retained animated art.

Source of truth: user-supplied retail Sonic 2 disassembly.
Outputs are deterministic and intentionally limited to Emerald Hill presentation data.
"""
from __future__ import annotations
import json, math, struct, sys
from collections import deque
from pathlib import Path

MUSIC_BASE = 0x1380
PORT_MUSIC_ID = 0x194
MIX_RATE = 22050.0

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data" / "s1"
S2TEST = OUT / "s2test"
SOUND = OUT / "sound"


def saxman_decompress(data: bytes) -> bytes:
    if len(data) < 2:
        raise ValueError("Saxman input too short")
    packed_len = int.from_bytes(data[:2], "little")
    src = 2
    end = min(len(data), 2 + packed_len)
    out = bytearray()
    while src < end:
        desc = data[src]
        src += 1
        for bit in range(8):
            if src >= end:
                break
            if desc & (1 << bit):
                out.append(data[src])
                src += 1
            else:
                if src + 1 >= end:
                    raise ValueError("truncated Saxman match")
                b1, b2 = data[src], data[src + 1]
                src += 2
                source = (((b2 >> 4) << 8) | b1) + 0x12
                source &= 0xFFF
                count = (b2 & 0x0F) + 3
                for _ in range(count):
                    out.append(out[source] if source < len(out) else 0)
                    source += 1
    return bytes(out)


def s8(v: int) -> int:
    return v - 0x100 if v & 0x80 else v


def read_u16le(data: bytes, off: int) -> int:
    return data[off] | (data[off + 1] << 8)


def label(kind: str, off: int) -> str:
    prefix = "D" if kind == "DAC" else ("P" if kind == "PSG" else "F")
    return f"S2EHZ_{prefix}_{off:04X}"


def parse_song(song: bytes) -> dict:
    voice_off = read_u16le(song, 0) - MUSIC_BASE
    fm_count, psg_count, tempo_div, tempo = song[2], song[3], song[4], song[5]
    p = 6
    channels = []
    starts = []
    for i in range(fm_count):
        off = read_u16le(song, p) - MUSIC_BASE
        transpose = s8(song[p + 2])
        volume = song[p + 3]
        p += 4
        kind = "DAC" if i == 0 else "FM"
        spec = {"kind": kind, "label": label(kind, off), "transpose": transpose, "volume": volume, "pan": "center"}
        channels.append(spec)
        starts.append((kind, off))
    for _ in range(psg_count):
        off = read_u16le(song, p) - MUSIC_BASE
        transpose = s8(song[p + 2])
        volume = song[p + 3]
        freq_env = song[p + 4]
        psg_voice = song[p + 5]
        p += 6
        spec = {"kind": "PSG", "label": label("PSG", off), "transpose": transpose, "volume": volume,
                "freq_env": freq_env, "psg_voice": psg_voice, "pan": "center"}
        channels.append(spec)
        starts.append(("PSG", off))

    labels = {}
    fallthrough = {}
    seen = set()
    todo = deque(starts)
    coord_argc = {
        0xE0: 1, 0xE1: 1, 0xE2: 1, 0xE3: 0, 0xE4: 0, 0xE5: 1, 0xE6: 1, 0xE7: 0,
        0xE8: 1, 0xE9: 1, 0xEA: 1, 0xEB: 1, 0xEC: 1, 0xED: 0, 0xEE: 0, 0xEF: 1,
        0xF0: 4, 0xF1: 0, 0xF2: 0, 0xF3: 1, 0xF4: 0, 0xF5: 1, 0xF6: 2, 0xF7: 4,
        0xF8: 2, 0xF9: 0,
    }
    used_dac = set()
    while todo:
        kind, off = todo.popleft()
        key = (kind, off)
        if key in seen:
            continue
        seen.add(key)
        if not 0 <= off < voice_off:
            raise ValueError(f"track address outside music stream: {kind} {off:#x}")
        b = song[off]
        seq = []
        next_off = off + 1
        successors = []
        if b < 0x80:
            seq.append(["duration", 256 if b == 0 else b])
            successors.append(next_off)
        elif b < 0xE0:
            if kind == "DAC":
                sample = -1 if b == 0x80 else b - 0x81
                if sample >= 0:
                    used_dac.add(sample)
                seq.append(["dac", sample])
            else:
                seq.append(["note", -1 if b == 0x80 else b - 0x81])
            if next_off < voice_off and song[next_off] < 0x80:
                dur = song[next_off]
                seq.append(["duration", 256 if dur == 0 else dur])
                next_off += 1
            successors.append(next_off)
        else:
            if b not in coord_argc:
                raise ValueError(f"unknown S2 coordination flag {b:#04x} at {off:#x}")
            argc = coord_argc[b]
            args = song[next_off:next_off + argc]
            if len(args) != argc:
                raise ValueError("truncated coordination flag")
            end = next_off + argc
            if b == 0xE0:
                panbits = args[0] & 0xC0
                pan = "left" if panbits == 0x80 else ("right" if panbits == 0x40 else "center")
                seq.append(["pan", pan, args[0] & 0x3F])
                successors.append(end)
            elif b == 0xE1:
                seq.append(["alter_note", args[0]])
                successors.append(end)
            elif b == 0xE2:
                seq.append(["s2_communication", args[0]])
                successors.append(end)
            elif b == 0xE3:
                seq.append(["return"])
            elif b == 0xE4:
                seq.append(["fade"])
                successors.append(end)
            elif b == 0xE5:
                seq.append(["tempo_div", args[0]])
                successors.append(end)
            elif b in (0xE6, 0xEC):
                seq.append(["alter_vol", s8(args[0])])
                successors.append(end)
            elif b == 0xE7:
                seq.append(["no_attack"])
                successors.append(end)
            elif b == 0xE8:
                seq.append(["note_fill", args[0]])
                successors.append(end)
            elif b == 0xE9:
                seq.append(["alter_pitch", s8(args[0])])
                successors.append(end)
            elif b == 0xEA:
                seq.append(["tempo_mod", args[0]])
                successors.append(end)
            elif b == 0xEB:
                seq.append(["tempo_div_all", args[0]])
                successors.append(end)
            elif b in (0xED, 0xEE, 0xF9):
                seq.append(["s2_nop"])
                successors.append(end)
            elif b == 0xEF:
                seq.append(["set_voice", args[0]])
                successors.append(end)
            elif b == 0xF0:
                seq.append(["mod_set", args[0], args[1], args[2], args[3]])
                successors.append(end)
            elif b == 0xF1:
                seq.append(["mod_on"])
                successors.append(end)
            elif b == 0xF2:
                seq.append(["stop"])
            elif b == 0xF3:
                seq.append(["psg_form", args[0]])
                successors.append(end)
            elif b == 0xF4:
                seq.append(["mod_off"])
                successors.append(end)
            elif b == 0xF5:
                seq.append(["psg_voice", args[0]])
                successors.append(end)
            elif b == 0xF6:
                target = read_u16le(args, 0) - MUSIC_BASE
                seq.append(["jump", label(kind, target)])
                successors.append(target)
            elif b == 0xF7:
                target = read_u16le(args, 2) - MUSIC_BASE
                seq.append(["loop", args[0], args[1], label(kind, target)])
                successors.extend([end, target])
            elif b == 0xF8:
                target = read_u16le(args, 0) - MUSIC_BASE
                seq.append(["call", label(kind, target)])
                successors.extend([end, target])
        here = label(kind, off)
        labels[here] = seq
        # Each address is its own small label. This makes branch targets exact and
        # avoids reinterpreting unrelated bytes when a branch skips ahead.
        if successors and b not in (0xF6,):
            # Control flow after loop/call must resume at the encoded end; for
            # ordinary instructions this is the single fall-through successor.
            normal = successors[0]
            fallthrough[here] = label(kind, normal)
        for target in successors:
            todo.append((kind, target))

    # Decode the 9x25-byte YM voice table. Store arrays in the same logical order
    # as the existing S1 JSON: reversed relative to raw YM register order because
    # SonicAudio's SMPS_MUSIC_OPERATOR_MAP resolves them back to hardware 1..4.
    voices = []
    if voice_off < 0 or voice_off > len(song):
        raise ValueError("bad EHZ voice pointer")
    count = (len(song) - voice_off) // 25
    for vi in range(count):
        raw = song[voice_off + vi * 25:voice_off + (vi + 1) * 25]
        if len(raw) < 25:
            break
        def rev(vals): return list(reversed(vals))
        dtmul = raw[1:5]; rsar = raw[5:9]; amd1r = raw[9:13]; d2r = raw[13:17]; d1lrr = raw[17:21]; tl = raw[21:25]
        voices.append({
            "algorithm": raw[0] & 7, "feedback": (raw[0] >> 3) & 7, "unused": 0,
            "detune": rev([(x >> 4) & 7 for x in dtmul]), "mul": rev([x & 0xF for x in dtmul]),
            "rate_scale": rev([(x >> 6) & 3 for x in rsar]), "attack": rev([x & 0x1F for x in rsar]),
            "amp_mod": rev([(x >> 7) & 1 for x in amd1r]), "decay1": rev([x & 0x1F for x in amd1r]),
            "decay2": rev([x & 0x1F for x in d2r]),
            "decay_level": rev([(x >> 4) & 0xF for x in d1lrr]), "release": rev([x & 0xF for x in d1lrr]),
            "total_level": rev([x & 0x7F for x in tl]),
        })

    # First three retail S2 PSG flutter envelopes are exactly the ones EHZ uses.
    psg_envs = [
        [0,0,0,1,1,1,2,2,2,3,3,3,4,4,4,5,5,5,6,6,6,7],
        [0,2,4,6,8,0x10],
        [0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7],
        [0,0,2,3,4,4,5,5,5,6],
        [0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2,3,3,3,3,3,3,3,3,4],
        [3,3,3,2,2,2,2,1,1,1,0,0,0,0],
        [0,0,0,0,0,0,1,1,1,1,1,2,2,2,2,2,3,3,3,4,4,4,5,5,5,6,7],
        [0,0,0,0,0,1,1,1,1,1,2,2,2,2,2,2,3,3,3,3,3,4,4,4,4,4,5,5,5,5,5,6,6,6,6,6,7,7,7],
        [0,1,2,3,4,5,6,7,8,9,0xA,0xB,0xC,0xD,0xE,0xF],
        [0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2,2,2,3,3,3,3,3,3,3,3,3,3,3,3,4],
        [4,4,4,3,3,3,2,2,2,1,1,1,1,1,1,1,2,2,2,2,2,3,3,3,3,3,4],
        [4,4,3,3,2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,7],
        [0xE,0xD,0xC,0xB,0xA,9,8,7,6,5,4,3,2,1,0],
    ]
    return {
        "id": PORT_MUSIC_ID,
        "name": "Sonic 2 - Emerald Hill Zone",
        "type": "music",
        "header": {
            "channels": channels, "voice_label": "S2EHZ_Voices", "fm_count": fm_count,
            "psg_count": psg_count, "tempo_div": tempo_div, "tempo_mod": tempo,
            "driver_mode": "s2", "speed_tempo": 0xBE,
        },
        "labels": labels, "fallthrough": fallthrough, "voices": voices,
        "psg_envelopes": psg_envs,
        "source": {"format": "S2 Saxman SMPS", "base": MUSIC_BASE, "used_dac_ids": sorted(used_dac)},
    }


def decode_s2_dac(raw: bytes) -> list[float]:
    delta = [0,1,2,4,8,0x10,0x20,0x40,-0x80,-1,-2,-4,-8,-0x10,-0x20,-0x40]
    v = 0x80
    out = []
    for b in raw:
        for nib in (b >> 4, b & 0xF):
            v = (v + delta[nib]) & 0xFF
            out.append((v - 128) / 128.0)
    return out


def resample_linear(samples: list[float], source_rate: float, target_rate: float) -> list[float]:
    if not samples:
        return []
    out_n = max(1, int(round(len(samples) * target_rate / source_rate)))
    result = []
    step = source_rate / target_rate
    for i in range(out_n):
        x = i * step
        j = min(int(x), len(samples) - 1)
        k = min(j + 1, len(samples) - 1)
        f = x - j
        result.append(samples[j] * (1.0 - f) + samples[k] * f)
    return result


def write_pcm16(path: Path, values: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as f:
        for x in values:
            v = max(-32768, min(32767, int(round(x * 32767.0))))
            f.write(struct.pack("<h", v))


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: import_s2_ehz_presentation.py <retail Sonic 2 disassembly root>", file=sys.stderr)
        return 2
    s2 = Path(sys.argv[1]).resolve()
    music_path = s2 / "sound" / "music" / "EHZ.bin"
    decomp = saxman_decompress(music_path.read_bytes())
    song = parse_song(decomp)
    music_json = {"music": {str(PORT_MUSIC_ID): song}}
    (SOUND / "s2_ehz_smps.json").write_text(json.dumps(music_json, indent=2) + "\n", encoding="utf-8")

    playlist = {
        0: (1, 0x17),   # raw note $81
        1: (2, 0x01),   # $82
        11: (6, 0x02),  # $8C
        13: (6, 0x08),  # $8E
    }
    for event_id, (sample_no, delay) in playlist.items():
        raw = (s2 / "sound" / "DAC" / f"Sample {sample_no}.bin").read_bytes()
        decoded = decode_s2_dac(raw)
        rate = 3579540.0 / (60.0 + delay * 4.0) / 2.0
        values = resample_linear(decoded, rate, MIX_RATE)
        write_pcm16(SOUND / f"s2_ehz_dac_{event_id:02d}.pcm", values)

    animated = {
        "s2_ehz_flowers1.bin": s2 / "art" / "uncompressed" / "EHZ and HTZ flowers - 1.bin",
        "s2_ehz_flowers2.bin": s2 / "art" / "uncompressed" / "EHZ and HTZ flowers - 2.bin",
        "s2_ehz_flowers3.bin": s2 / "art" / "uncompressed" / "EHZ and HTZ flowers - 3.bin",
        "s2_ehz_flowers4.bin": s2 / "art" / "uncompressed" / "EHZ and HTZ flowers - 4.bin",
        "s2_ehz_pulse.bin": s2 / "art" / "uncompressed" / "Pulsing ball against checkered background (EHZ).bin",
    }
    S2TEST.mkdir(parents=True, exist_ok=True)
    for name, src in animated.items():
        (S2TEST / name).write_bytes(src.read_bytes())

    print(f"EHZ decompressed song: {len(decomp)} bytes; {len(song['voices'])} voices; {len(song['labels'])} graph labels")
    print(f"Wrote music ID ${PORT_MUSIC_ID:X}, four source DAC variants, and five animated-art sources")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
