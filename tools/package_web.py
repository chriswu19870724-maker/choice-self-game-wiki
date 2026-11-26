"""Package a Godot Web export for Sites' static asset size limit."""

import argparse
import gzip
from pathlib import Path
import shutil


WASM_LOADER = """<script>
// Keep the compressed Godot WebAssembly under the static host's asset limit.
const godotWasmURL = new URL('index.wasm', document.baseURI).href;
const originalFetch = window.fetch.bind(window);
window.fetch = async (input, options) => {
    if (typeof input !== 'string' || new URL(input, document.baseURI).href !== godotWasmURL) {
        return originalFetch(input, options);
    }
    const payload = await originalFetch(godotWasmURL + '.gz', options);
    if (!payload.ok) return payload;
    return new Response(payload.body.pipeThrough(new DecompressionStream('gzip')), {
        headers: { 'Content-Type': 'application/wasm', 'Content-Length': '%d' },
    });
};
</script>
"""


def package(source: Path, destination: Path) -> None:
    html = (source / 'index.html').read_text(encoding='utf-8')
    wasm = source / 'index.wasm'
    loader_marker = '<script src="index.js"></script>'
    if html.count(loader_marker) != 1:
        raise ValueError('Godot export does not have the expected script entry point')

    destination.mkdir(parents=True, exist_ok=False)
    for file in sorted(source.iterdir()):
        if file.is_file() and file.name not in {'index.html', 'index.wasm'}:
            shutil.copyfile(file, destination / file.name)
    with wasm.open('rb') as original, (destination / 'index.wasm.gz').open('wb') as compressed:
        with gzip.GzipFile(filename='', fileobj=compressed, mode='wb', mtime=0) as stream:
            shutil.copyfileobj(original, stream)
    html = html.replace(loader_marker, (WASM_LOADER % wasm.stat().st_size) + loader_marker)
    (destination / 'index.html').write_text(html, encoding='utf-8')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('export', type=Path, help='Godot Web export directory')
    parser.add_argument('destination', type=Path, help='New static deployment directory')
    args = parser.parse_args()
    package(args.export, args.destination)
