#!/usr/bin/env python3
import json,pathlib,re,sys
root=pathlib.Path(__file__).resolve().parents[1]
data=json.loads((root/'appliance.json').read_text())
errors=[]
if data.get('schema')!='ores.desktop-appliance/v1': errors.append('unexpected schema')
if data.get('product')!='beamscale': errors.append('product must be beamscale')
host=data.get('host',{})
if host.get('daemon_listen')!='127.0.0.1:9587': errors.append('daemon must bind 127.0.0.1:9587')
if host.get('public_origin')!='http://127.0.0.1:8080': errors.append('public origin must be loopback :8080')
if host.get('default_reverse_proxy')!='none': errors.append('default reverse proxy must be none')
seen=set()
for section in ('components','clients'):
 for c in data.get(section,[]):
  name=c.get('name'); rev=c.get('rev','')
  key=(section,name)
  if not name or key in seen: errors.append(section+': duplicate/missing component name')
  seen.add(key)
  if not re.fullmatch(r'[0-9a-f]{40}',rev): errors.append(str(name)+': rev must be exact SHA')
  if not str(c.get('repo','')).startswith('beamscale/'): errors.append(str(name)+': repo must be beamscale/*')
required={'desktop-daemon','supervisor','compiler','cli'}
component_names={c.get('name') for c in data.get('components',[])}
if required-component_names: errors.append('missing components: '+','.join(sorted(required-component_names)))
if data.get('cloudflare',{}).get('origin')!=host.get('public_origin'): errors.append('Cloudflare origin must equal host public_origin')
if data.get('update',{}).get('allow_mutable_latest') is not False: errors.append('mutable latest must be forbidden')
if data.get('cloudflare',{}).get('credentials_in_repo') is not False: errors.append('Cloudflare credentials must stay out of repo')
if data.get('channel')=='promoted' and not all(data.get('promotion_gates',{}).values()): errors.append('promoted channel requires all gates')
if errors:
 print('\n'.join('ERROR: '+e for e in errors),file=sys.stderr); raise SystemExit(1)
print('BeamScale appliance manifest OK; channel='+str(data.get('channel')))
