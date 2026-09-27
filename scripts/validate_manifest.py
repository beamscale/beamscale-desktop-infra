#!/usr/bin/env python3
import json,pathlib,re,sys
root=pathlib.Path(__file__).resolve().parents[1]
data=json.loads((root/'appliance.json').read_text())
errors=[]
if data.get('schema')!='ores.desktop-appliance/v1': errors.append('unexpected schema')
if data.get('product')!='beamscale': errors.append('product must be beamscale')
host=data.get('host',{})
if host.get('daemon_listen')!='127.0.0.1:9587': errors.append('daemon must bind 127.0.0.1:9587')
if host.get('public_origin')!='http://127.0.0.1:8081': errors.append('public origin must be loopback :8081')
if host.get('default_reverse_proxy')!='none': errors.append('default reverse proxy must be none')
seen=set()
for c in data.get('components',[]):
 name=c.get('name'); rev=c.get('rev','')
 if not name or name in seen: errors.append('duplicate/missing component name')
 seen.add(name)
 if not re.fullmatch(r'[0-9a-f]{40}',rev): errors.append(str(name)+': rev must be exact SHA')
 if not str(c.get('repo','')).startswith('beamscale/'): errors.append(str(name)+': repo must be beamscale/*')
required={'desktop-daemon','supervisor','compiler','cli'}
if required-seen: errors.append('missing components: '+','.join(sorted(required-seen)))
if data.get('update',{}).get('allow_mutable_latest') is not False: errors.append('mutable latest must be forbidden')
if data.get('cloudflare',{}).get('credentials_in_repo') is not False: errors.append('Cloudflare credentials must stay out of repo')
if errors:
 print('\n'.join('ERROR: '+e for e in errors),file=sys.stderr); raise SystemExit(1)
print('BeamScale appliance manifest OK; channel='+str(data.get('channel')))
