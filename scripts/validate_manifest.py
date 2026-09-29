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
profiles=data.get('cli_profiles',{})
end_user=profiles.get('end_user',{})
alternate=profiles.get('alternate_end_user',{})
if end_user.get('command')!='bmscl' or end_user.get('implementation')!='rust' or end_user.get('audience')!='external' or end_user.get('canonical') is not True:
 errors.append('end_user CLI profile must be canonical external Rust bmscl')
if alternate.get('command')!='bmscl-gleam' or alternate.get('implementation')!='gleam' or alternate.get('audience')!='external' or alternate.get('canonical') is not False:
 errors.append('alternate_end_user CLI profile must be optional external Gleam bmscl-gleam')
component_by_name={c.get('name'):c for c in data.get('components',[])}
client_by_name={c.get('name'):c for c in data.get('clients',[])}
if component_by_name.get('cli',{}).get('role')!='end-user-cli':
 errors.append('components/cli must be role=end-user-cli')
if client_by_name.get('cli-gleam',{}).get('role')!='alternate-end-user-cli':
 errors.append('clients/cli-gleam must be role=alternate-end-user-cli')
if end_user.get('source')!='components/cli': errors.append('end_user CLI must source components/cli')
if alternate.get('source')!='clients/cli-gleam': errors.append('alternate end-user CLI must source clients/cli-gleam')
if data.get('channel')=='promoted' and not all(data.get('promotion_gates',{}).values()): errors.append('promoted channel requires all gates')
if errors:
 print('\n'.join('ERROR: '+e for e in errors),file=sys.stderr); raise SystemExit(1)
print('BeamScale appliance manifest OK; channel='+str(data.get('channel')))
