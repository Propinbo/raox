"""Inventory actual JARs (including nested copies) and query exact Maven versions.

Python 3.11+, standard library only. An empty OSV result is not proof of safety.
"""
import argparse
import csv
import hashlib
import io
import json
import pathlib
import urllib.request
import xml.etree.ElementTree as ET
import zipfile
from datetime import datetime, timezone


def properties(data):
    return dict(line.strip().split('=', 1) for line in data.decode('utf-8', 'replace').splitlines()
                if '=' in line and not line.startswith('#'))


def manifest(data):
    data = data.decode('utf-8', 'replace').replace('\r', '').replace('\n ', '')
    return dict(line.split(': ', 1) for line in data.splitlines() if ': ' in line)


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--plugins', type=pathlib.Path, required=True)
    parser.add_argument('--metadata', type=pathlib.Path)
    parser.add_argument('--maven', type=pathlib.Path)
    parser.add_argument('--output', type=pathlib.Path, required=True)
    parser.add_argument('--query-osv', action='store_true')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    embedded_lock = json.loads((pathlib.Path(__file__).parent / 'embedded-libraries.lock.json').read_text(encoding='utf-8-sig'))
    embedded_by_hash = {entry['sha256']: entry for entry in embedded_lock['libraries']}
    coords = {}
    if args.metadata:
        for unit in ET.parse(args.metadata).getroot().findall('./units/unit'):
            props = {p.get('name'): p.get('value') for p in unit.findall('./properties/property')}
            if all(props.get('maven-' + k) for k in ['groupId', 'artifactId', 'version']):
                coords[(unit.get('id'), unit.get('version'))] = [props['maven-' + k]
                                                               for k in ['groupId', 'artifactId', 'version']]
    components = []

    def inspect(data, path, scope, fallback=None):
        sha256 = hashlib.sha256(data).hexdigest()
        known_binary = embedded_by_hash.get(sha256)
        with zipfile.ZipFile(io.BytesIO(data)) as jar:
            mf = manifest(jar.read('META-INF/MANIFEST.MF')) if 'META-INF/MANIFEST.MF' in jar.namelist() else {}
            bsn = mf.get('Bundle-SymbolicName', '').split(';')[0]
            version = mf.get('Bundle-Version', mf.get('Implementation-Version', 'unknown'))
            coordinate = coords.get((bsn, version), fallback)
            if known_binary:
                coordinate = known_binary['coordinate'].split(':')
            embedded = []
            for name in jar.namelist():
                if name.startswith('META-INF/maven/') and name.endswith('/pom.properties'):
                    p = properties(jar.read(name))
                    if all(k in p for k in ['groupId', 'artifactId', 'version']):
                        embedded.append([p[k] for k in ['groupId', 'artifactId', 'version']])
            if not coordinate and len(embedded) == 1:
                coordinate = embedded[0]
            component = {'type': 'library', 'name': bsn or pathlib.Path(path).name, 'version': version,
                         'bom-ref': path, 'hashes': [{'alg': 'SHA-256', 'content': sha256}],
                         'properties': [{'name': 'raox:scope', 'value': scope},
                                        {'name': 'raox:path', 'value': path}]}
            if coordinate:
                g, a, v = coordinate
                component.update(group=g, name=a, version=v, purl=f'pkg:maven/{g}/{a}@{v}')
            if mf.get('Bundle-License'):
                component['properties'].append({'name': 'raox:bundle-license', 'value': mf['Bundle-License']})
            if known_binary:
                component['licenses'] = [{'license': {'id': known_binary['license']}}]
            components.append(component)
            if bsn == 'ru.bmstu.rk9.rao.lib':
                components.append({'type': 'library', 'name': 'JSON.org modified source copy', 'version': '2014-05-03',
                    'bom-ref': path + '!ru.bmstu.rk9.rao.lib.json', 'licenses': [{'license': {'id': 'JSON'}}],
                    'properties': [{'name': 'raox:scope', 'value': scope},
                                   {'name': 'raox:provenance', 'value': 'Modified namespace and ordered maps; exact Maven version unknown'}]})
            if bsn == 'ru.bmstu.rk9.rao.ui':
                components.append({'type': 'library', 'name': 'jfreechart-swt',
                    'version': embedded_lock['swt_adapter_commit'], 'bom-ref': path + '!org.jfree.chart.swt',
                    'licenses': [{'license': {'id': 'LGPL-2.1-or-later'}}],
                    'properties': [{'name': 'raox:scope', 'value': scope},
                                   {'name': 'raox:provenance', 'value': 'Pinned upstream source revision; no released Maven coordinate'}]})
            for index, (g, a, v) in enumerate(embedded):
                if [g, a, v] != coordinate:
                    components.append({'type': 'library', 'group': g, 'name': a, 'version': v,
                                       'purl': f'pkg:maven/{g}/{a}@{v}', 'bom-ref': path + f'!embedded-{index}',
                                       'properties': [{'name': 'raox:scope', 'value': scope},
                                                      {'name': 'raox:embedded-metadata', 'value': path}]})
            for name in jar.namelist():
                if name.lower().endswith('.jar'):
                    inspect(jar.read(name), path + '!' + name, scope)

    for file in sorted(args.plugins.rglob('*.jar')):
        inspect(file.read_bytes(), file.relative_to(args.plugins).as_posix(), 'runtime')
    if args.maven:
        for file in sorted(args.maven.rglob('*.jar')):
            relative = file.relative_to(args.maven)
            if relative.parts[0] in ['p2', '.cache', '.wrapper', '.meta']:
                continue
            parts = relative.parts
            inspect(file.read_bytes(), 'maven/' + relative.as_posix(), 'build-cache',
                    ['.'.join(parts[:-3]), parts[-3], parts[-2]])
    sbom = {'bomFormat': 'CycloneDX', 'specVersion': '1.5', 'version': 1,
            'metadata': {'timestamp': datetime.now(timezone.utc).isoformat(),
                         'component': {'type': 'application', 'name': 'Rao X Windows x64', 'version': '3.9.0'}},
            'components': components}
    (args.output / 'sbom.cdx.json').write_text(json.dumps(sbom, indent=2, ensure_ascii=False), encoding='utf-8')
    if args.query_osv:
        packages = sorted({(c['group'] + ':' + c['name'], c['version']) for c in components if 'purl' in c})
        results = []
        for offset in range(0, len(packages), 100):
            batch = packages[offset:offset + 100]
            body = {'queries': [{'package': {'ecosystem': 'Maven', 'name': n}, 'version': v} for n, v in batch]}
            request = urllib.request.Request('https://api.osv.dev/v1/querybatch',
                                             data=json.dumps(body).encode(), headers={'Content-Type': 'application/json'})
            with urllib.request.urlopen(request, timeout=60) as response:
                answers = json.load(response)['results']
            for (name, version), answer in zip(batch, answers):
                matching = [c for c in components if c.get('group', '') + ':' + c['name'] == name and c['version'] == version]
                scopes = sorted({p['value'] for c in matching for p in c.get('properties', []) if p['name'] == 'raox:scope'})
                results.append({'package': name, 'version': version, 'scopes': scopes,
                                'components': [c['bom-ref'] for c in matching], 'vulnerabilities': answer.get('vulns', [])})
        report = {'queried_at_utc': datetime.now(timezone.utc).isoformat(), 'endpoint': 'https://api.osv.dev/v1/querybatch',
                  'unmapped_components': [c['bom-ref'] for c in components if 'purl' not in c], 'results': results}
        (args.output / 'osv-results.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(f'Inventoried {len(components)} components; {sum("purl" in c for c in components)} Maven mappings.')


if __name__ == '__main__':
    main()
