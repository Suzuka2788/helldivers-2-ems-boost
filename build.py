"""Package the EMS balance settings as Suzuka's v1.0.9 release."""
from pathlib import Path
import hashlib
import json
import struct
import sys
import zipfile

HERE = Path(__file__).resolve().parent
from archive import ARCHIVE, make_archive, resource_hash
from ems_data import sample_record, GAME, GAME_SHA

RESOURCE = 'mods/suzuka/ems_boost'
OUTPUT = HERE / 'Suzukas-EMS-boos-v1.0.9.zip'


def build_source():
    mapping, row = sample_record()
    source = '-- HD2-Addon: ' + RESOURCE + '\n'
    for name, path in [('component_policy', HERE / 'component_patch.lua'),
                       ('create_api', HERE / 'windows_api.lua')]:
        source += f'local {name}=(function()\n{path.read_text(encoding="utf-8")}\nend)()\n'
    source += 'local function unhex(s)return(s:gsub("..",function(x)return string.char(tonumber(x,16))end))end\n'
    source += f"local module_sha256='{GAME_SHA}'\n"
    source += 'local owner_rva=0x3326B90\n'
    source += ('local component_specs={{label="EMS_2X4_AREA_15_HEIGHT_2700",'
               'scan_begin=0xf10000,scan_end=0xf13000,record_size=192,record_index=19,'
               'probe_offset=16,')
    source += f"map=unhex('{mapping.hex()}'),original=unhex('{row.hex()}'),"
    edits = [(4, struct.pack('<I', 4)), (8, struct.pack('<f', .25)),
             (24, struct.pack('<I', 2)), (28, struct.pack('<f', 3.0)),
             (36, struct.pack('<f', 15.0)), (44, struct.pack('<f', 2700.0))]
    source += 'edits={' + ','.join("{offset=%d,bytes=unhex('%s')}" % (offset, data.hex())
                                  for offset, data in edits) + '}}}\n'
    source += (HERE / 'entry.lua').read_text(encoding='utf-8')
    return source.encode('utf-8')


def build():
    actual = hashlib.sha256(GAME.read_bytes()).hexdigest()
    if actual != GAME_SHA:
        raise RuntimeError(f'game.dll changed: {actual}; reverify before building')
    source = build_source()
    archive = make_archive({resource_hash(RESOURCE): struct.pack('<II', len(source), 2) + source})
    manifest = {'Version': 1, 'Guid': 'fead8be8-4c65-4a8a-a23a-21758247c033',
                'Name': 'Suzuka‘s EMS boos v1.0.9',
                'Description': 'Two salvos of four EMS bombs, area 15, 0.25 s bomb interval. Requires Bingus Shared Loader API 1.'}
    with zipfile.ZipFile(OUTPUT, 'w', compression=zipfile.ZIP_DEFLATED) as out:
        out.writestr('manifest.json', json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
        out.writestr(ARCHIVE, archive)
        out.writestr(ARCHIVE + '.stream', b'')
        out.writestr(ARCHIVE + '.gpu_resources', b'')
    with zipfile.ZipFile(OUTPUT) as out:
        assert source in out.read(ARCHIVE)
    print(OUTPUT)


if __name__ == '__main__':
    build()
