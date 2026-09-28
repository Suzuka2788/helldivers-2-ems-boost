"""Reference data shared by EMS preview builders."""
from pathlib import Path
import gzip
import hashlib
import struct

HERE = Path(__file__).resolve().parent
SAMPLE = HERE / 'generated_entities.20260922.dl_bin.gz'
GAME = Path(r'C:\Program Files (x86)\Steam\steamapps\common\Helldivers 2\data\game\game.dll')
SAMPLE_SHA = '21377252b81fdbc670eba1e59a8ab64b170323df208f175e708992e4c1fb515e'
GAME_SHA = '2e2c3b7c2500646dadd5f2b4c6e0504dbb7e7896139f64cddc0d1813c718f51e'
EMS_HASH = 0x55F3747B8C27AEF6
RESOURCE = 'mods/tongz/orbital_ems_suppression'


def dlhash(name):
    value = 5381
    for byte in name.encode():
        value = (value * 33 + byte) & 0xffffffff
    return (value - 5381) & 0xffffffff


def sample_record():
    blob = gzip.decompress(SAMPLE.read_bytes())
    assert hashlib.sha256(blob).hexdigest() == SAMPLE_SHA
    header = struct.pack('<III', 0x444c444c, 1, dlhash('BombardmentComponentData'))
    assert blob.count(header) == 1
    position = blob.index(header)
    body_size = struct.unpack_from('<I', blob, position + 12)[0]
    body = blob[position + 24:position + 24 + body_size]
    assert body_size == 5120
    mapping = body[:704]
    rows = body[704:]
    assert len(rows) == 23 * 192
    hits = [(slot, index) for slot in range(44)
            for identity, index, reserved in [struct.unpack_from('<QII', mapping, slot * 16)]
            if identity == EMS_HASH and reserved == 0]
    assert hits == [(39, 19)]
    row = rows[19 * 192:20 * 192]
    assert struct.unpack_from('<I', row, 4)[0] == 1
    assert struct.unpack_from('<f', row, 8)[0] == struct.unpack('<f', struct.pack('<f', .35))[0]
    assert struct.unpack_from('<If', row, 24) == (1, 2.0)
    assert struct.unpack_from('<f', row, 36)[0] == 1.0
    assert struct.unpack_from('<f', row, 44)[0] == 3000.0
    assert struct.unpack_from('<I', row, 60)[0] == 1
    assert struct.unpack_from('<I', row, 64)[0] == 74
    return mapping, row
