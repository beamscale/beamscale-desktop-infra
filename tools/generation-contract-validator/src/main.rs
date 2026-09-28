use std::{collections::BTreeMap, env, fs, path::Path};

const MAX_BYTES: u64 = 64 * 1024;

#[derive(Debug, Clone, PartialEq)]
enum Value {
    Null,
    Bool(bool),
    Number(u64),
    String(String),
    Array(Vec<Value>),
    Object(BTreeMap<String, Value>),
}

struct Parser<'a> {
    input: &'a [u8],
    pos: usize,
}

impl<'a> Parser<'a> {
    fn new(input: &'a [u8]) -> Self { Self { input, pos: 0 } }
    fn parse(mut self) -> Result<Value, String> {
        let value = self.value()?;
        self.ws();
        if self.pos != self.input.len() { return Err(format!("trailing data at byte {}", self.pos)); }
        Ok(value)
    }
    fn ws(&mut self) {
        while self.pos < self.input.len() && matches!(self.input[self.pos], b' ' | b'\n' | b'\r' | b'\t') {
            self.pos += 1;
        }
    }
    fn peek(&mut self) -> Option<u8> { self.ws(); self.input.get(self.pos).copied() }
    fn take(&mut self, byte: u8) -> Result<(), String> {
        self.ws();
        if self.input.get(self.pos) == Some(&byte) { self.pos += 1; Ok(()) }
        else { Err(format!("expected '{}' at byte {}", byte as char, self.pos)) }
    }
    fn value(&mut self) -> Result<Value, String> {
        match self.peek() {
            Some(b'{') => self.object(),
            Some(b'[') => self.array(),
            Some(b'"') => Ok(Value::String(self.string()?)),
            Some(b't') => { self.keyword(b"true")?; Ok(Value::Bool(true)) }
            Some(b'f') => { self.keyword(b"false")?; Ok(Value::Bool(false)) }
            Some(b'n') => { self.keyword(b"null")?; Ok(Value::Null) }
            Some(b'0'..=b'9') => self.number(),
            Some(other) => Err(format!("unexpected byte '{}' at {}", other as char, self.pos)),
            None => Err("unexpected end of input".into()),
        }
    }
    fn keyword(&mut self, word: &[u8]) -> Result<(), String> {
        self.ws();
        if self.input.get(self.pos..self.pos + word.len()) == Some(word) {
            self.pos += word.len();
            Ok(())
        } else {
            Err(format!("invalid token at byte {}", self.pos))
        }
    }
    fn number(&mut self) -> Result<Value, String> {
        self.ws();
        let start = self.pos;
        if self.input.get(self.pos) == Some(&b'0') { self.pos += 1; }
        else { while matches!(self.input.get(self.pos), Some(b'0'..=b'9')) { self.pos += 1; } }
        if matches!(self.input.get(self.pos), Some(b'.' | b'e' | b'E' | b'+' | b'-')) {
            return Err("only unsigned integer JSON numbers are accepted".into());
        }
        let text = std::str::from_utf8(&self.input[start..self.pos]).map_err(|_| "invalid utf-8 in number")?;
        Ok(Value::Number(text.parse().map_err(|_| "invalid integer")?))
    }
    fn string(&mut self) -> Result<String, String> {
        self.take(b'"')?;
        let mut out = String::new();
        while self.pos < self.input.len() {
            let b = self.input[self.pos];
            self.pos += 1;
            match b {
                b'"' => return Ok(out),
                b'\\' => {
                    let esc = *self.input.get(self.pos).ok_or("unterminated escape")?;
                    self.pos += 1;
                    match esc {
                        b'"' => out.push('"'),
                        b'\\' => out.push('\\'),
                        b'/' => out.push('/'),
                        b'b' => out.push('\u{0008}'),
                        b'f' => out.push('\u{000c}'),
                        b'n' => out.push('\n'),
                        b'r' => out.push('\r'),
                        b't' => out.push('\t'),
                        b'u' => {
                            let end = self.pos + 4;
                            let hex = self.input.get(self.pos..end).ok_or("short unicode escape")?;
                            let hex = std::str::from_utf8(hex).map_err(|_| "invalid unicode escape")?;
                            let code = u16::from_str_radix(hex, 16).map_err(|_| "invalid unicode escape")?;
                            self.pos = end;
                            let ch = char::from_u32(code as u32).ok_or("unsupported unicode escape")?;
                            out.push(ch);
                        }
                        _ => return Err("invalid string escape".into()),
                    }
                }
                0x00..=0x1f => return Err("control byte in string".into()),
                0x20..=0x7f => out.push(b as char),
                _ => return Err("non-ascii contract strings are not accepted".into()),
            }
        }
        Err("unterminated string".into())
    }
    fn array(&mut self) -> Result<Value, String> {
        self.take(b'[')?;
        let mut values = Vec::new();
        if self.peek() == Some(b']') { self.pos += 1; return Ok(Value::Array(values)); }
        loop {
            values.push(self.value()?);
            match self.peek() {
                Some(b',') => self.pos += 1,
                Some(b']') => { self.pos += 1; break; }
                _ => return Err(format!("expected ',' or ']' at byte {}", self.pos)),
            }
        }
        Ok(Value::Array(values))
    }
    fn object(&mut self) -> Result<Value, String> {
        self.take(b'{')?;
        let mut values = BTreeMap::new();
        if self.peek() == Some(b'}') { self.pos += 1; return Ok(Value::Object(values)); }
        loop {
            if self.peek() != Some(b'"') { return Err(format!("expected object key at byte {}", self.pos)); }
            let key = self.string()?;
            self.take(b':')?;
            let value = self.value()?;
            if values.insert(key.clone(), value).is_some() { return Err(format!("duplicate object key: {key}")); }
            match self.peek() {
                Some(b',') => self.pos += 1,
                Some(b'}') => { self.pos += 1; break; }
                _ => return Err(format!("expected ',' or '}}' at byte {}", self.pos)),
            }
        }
        Ok(Value::Object(values))
    }
}

fn obj<'a>(v: &'a Value, name: &str) -> Result<&'a BTreeMap<String, Value>, String> {
    match v { Value::Object(v) => Ok(v), _ => Err(format!("{name} must be an object")) }
}
fn field<'a>(o: &'a BTreeMap<String, Value>, key: &str) -> Result<&'a Value, String> {
    o.get(key).ok_or_else(|| format!("missing field: {key}"))
}
fn text<'a>(o: &'a BTreeMap<String, Value>, key: &str) -> Result<&'a str, String> {
    match field(o,key)? { Value::String(v)=>Ok(v), _=>Err(format!("{key} must be a string")) }
}
fn boolean(o:&BTreeMap<String,Value>, key:&str)->Result<bool,String>{
    match field(o,key)? { Value::Bool(v)=>Ok(*v), _=>Err(format!("{key} must be a boolean")) }
}
fn number(o:&BTreeMap<String,Value>, key:&str)->Result<u64,String>{
    match field(o,key)? { Value::Number(v)=>Ok(*v), _=>Err(format!("{key} must be an integer")) }
}
fn strings(o:&BTreeMap<String,Value>, key:&str)->Result<Vec<&str>,String>{
    match field(o,key)? {
        Value::Array(v)=>v.iter().map(|x|match x{
            Value::String(s)=>Ok(s.as_str()),
            _=>Err(format!("{key} must contain only strings"))
        }).collect(),
        _=>Err(format!("{key} must be an array"))
    }
}
fn exact_keys(o:&BTreeMap<String,Value>, expected:&[&str], name:&str)->Result<(),String>{
    let actual:Vec<&str>=o.keys().map(String::as_str).collect();
    let mut exp=expected.to_vec();
    exp.sort_unstable();
    if actual==exp{Ok(())}else{Err(format!("{name} keys mismatch: got {actual:?}, expected {exp:?}"))}
}
fn ensure(ok:bool,msg:&str)->Result<(),String>{if ok{Ok(())}else{Err(msg.into())}}

fn validate(root:&Value)->Result<(),String>{
    let r=obj(root,"root")?;
    exact_keys(r,&["schema","consumer","authority","lifecycle","rollback","request_semantics","routing","middleware","role_requirements","verification"],"root")?;
    ensure(text(r,"schema")?=="ores.desktop-generation-consumer/v1","unexpected schema")?;

    let c=obj(field(r,"consumer")?,"consumer")?;
    exact_keys(c,&["repository","role"],"consumer")?;
    ensure(text(c,"repository")?=="beamscale/beamscale-desktop-infra","unexpected consumer repository")?;
    ensure(text(c,"role")?=="desktop_infra","unexpected consumer role")?;

    let a=obj(field(r,"authority")?,"authority")?;
    exact_keys(a,&["repository","revision","pull_request"],"authority")?;
    ensure(text(a,"repository")?=="ORESoftware/ores-common-desktop-infra","unexpected authority repository")?;
    let rev=text(a,"revision")?;
    ensure(rev.len()==40 && rev.bytes().all(|b|b.is_ascii_digit()||(b'a'..=b'f').contains(&b)),"authority revision must be 40 lowercase hex chars")?;
    ensure(number(a,"pull_request")?>0,"authority pull request must be positive")?;

    ensure(strings(r,"lifecycle")?==["prepare","validate","compile_build_generation","stage","health_check","atomic_activate","bounded_drain","commit"],"unexpected lifecycle")?;

    let rb=obj(field(r,"rollback")?,"rollback")?;
    exact_keys(rb,&["required_before_commit","retain_previous_generation"],"rollback")?;
    ensure(boolean(rb,"required_before_commit")?&&boolean(rb,"retain_previous_generation")?,"rollback invariants must remain enabled")?;

    let rs=obj(field(r,"request_semantics")?,"request_semantics")?;
    exact_keys(rs,&["new_requests","existing_requests","generation_identity_required"],"request_semantics")?;
    ensure(text(rs,"new_requests")?=="active_generation"&&text(rs,"existing_requests")?=="pinned_generation"&&boolean(rs,"generation_identity_required")?,"request semantics changed")?;

    let rt=obj(field(r,"routing")?,"routing")?;
    exact_keys(rt,&["dynamic_route_authority","edge_proxy_route_authority","stable_edges"],"routing")?;
    ensure(text(rt,"dynamic_route_authority")?=="shared_router_generation"&&!boolean(rt,"edge_proxy_route_authority")?&&strings(rt,"stable_edges")?==["nginx","haproxy","caddy"],"routing invariants changed")?;

    let m=obj(field(r,"middleware")?,"middleware")?;
    exact_keys(m,&["parameter_changes","code_changes","beam_code_reload_requires_drain_or_otp_proof"],"middleware")?;
    ensure(text(m,"parameter_changes")?=="atomic_generation_swap"&&text(m,"code_changes")?=="wasm_generation_or_proven_beam_upgrade"&&boolean(m,"beam_code_reload_requires_drain_or_otp_proof")?,"middleware invariants changed")?;

    ensure(strings(r,"role_requirements")?==["build_stage_activate","health_before_activate","stable_ingress_only","no_dynamic_routes_in_edge_proxy"],"role requirements changed")?;

    let v=obj(field(r,"verification")?,"verification")?;
    exact_keys(v,&["shared_conformance_required","product_e2e_required","promotion_state"],"verification")?;
    ensure(boolean(v,"shared_conformance_required")?&&boolean(v,"product_e2e_required")?&&text(v,"promotion_state")?=="candidate","verification invariants changed")?;
    Ok(())
}

fn run(path:&Path)->Result<(),String>{
    let meta=fs::symlink_metadata(path).map_err(|e|format!("stat {}: {e}",path.display()))?;
    ensure(meta.file_type().is_file(),"contract path must be a regular file")?;
    ensure(meta.len()<=MAX_BYTES,"contract exceeds 64 KiB")?;
    let bytes=fs::read(path).map_err(|e|format!("read {}: {e}",path.display()))?;
    let parsed=Parser::new(&bytes).parse()?;
    validate(&parsed)
}

fn main(){
    let mut args=env::args_os().skip(1);
    let Some(path)=args.next() else {
        eprintln!("usage: generation-contract-validator <contract.json>");
        std::process::exit(2);
    };
    if args.next().is_some(){
        eprintln!("expected exactly one contract path");
        std::process::exit(2);
    }
    match run(Path::new(&path)){
        Ok(())=>println!("generation contract OK"),
        Err(e)=>{eprintln!("generation contract validation failed: {e}");std::process::exit(2)}
    }
}

#[cfg(test)]
mod tests{
    use super::*;
    const GOOD:&str=r#"{"schema":"ores.desktop-generation-consumer/v1","consumer":{"repository":"beamscale/beamscale-desktop-infra","role":"desktop_infra"},"authority":{"repository":"ORESoftware/ores-common-desktop-infra","revision":"895ed4e43f0d9a6bc39dfd4688e0b5009b1c10ef","pull_request":9},"lifecycle":["prepare","validate","compile_build_generation","stage","health_check","atomic_activate","bounded_drain","commit"],"rollback":{"required_before_commit":true,"retain_previous_generation":true},"request_semantics":{"new_requests":"active_generation","existing_requests":"pinned_generation","generation_identity_required":true},"routing":{"dynamic_route_authority":"shared_router_generation","edge_proxy_route_authority":false,"stable_edges":["nginx","haproxy","caddy"]},"middleware":{"parameter_changes":"atomic_generation_swap","code_changes":"wasm_generation_or_proven_beam_upgrade","beam_code_reload_requires_drain_or_otp_proof":true},"role_requirements":["build_stage_activate","health_before_activate","stable_ingress_only","no_dynamic_routes_in_edge_proxy"],"verification":{"shared_conformance_required":true,"product_e2e_required":true,"promotion_state":"candidate"}}"#;
    #[test] fn accepts_contract(){let v=Parser::new(GOOD.as_bytes()).parse().unwrap();assert!(validate(&v).is_ok())}
    #[test] fn rejects_duplicate_key(){assert!(Parser::new(br#"{"a":1,"a":2}"#).parse().is_err())}
    #[test] fn rejects_unknown_root_field(){let mut s=GOOD.to_owned();s.pop();s.push_str(",\"extra\":true}");let v=Parser::new(s.as_bytes()).parse().unwrap();assert!(validate(&v).is_err())}
}
