"""Restore original bytes from Git payload parts; never overwrite differing files."""
from pathlib import Path
import argparse,hashlib,json,zipfile,tempfile,shutil
R=Path(__file__).resolve().parent
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
 return h.hexdigest()
def safe(rel):
 p=(R/rel).resolve()
 if not p.is_relative_to(R):raise ValueError('outside repository: '+rel)
 return p
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--group',choices=['runtime','design','all'],default='runtime');ap.add_argument('--verify-only',action='store_true');a=ap.parse_args();m=json.loads((R/'HANDOFF_MANIFEST.json').read_text());groups=['runtime'] if a.group=='runtime' else (['runtime','design'] if a.group=='all' else ['runtime',a.group]);files=[r for r in m['files'] if r['group'] in groups+['plain']];by_path={r['path']:r for r in files}
 for row in files:
  p=safe(row['path'])
  if p.exists() and (p.stat().st_size!=row['bytes'] or sha(p)!=row['sha256']):raise SystemExit('Existing file differs; preserve it and use a clean checkout: '+row['path'])
 if not a.verify_only:
  for pack in m['packs']:
   if pack['group'] not in groups:continue
   with tempfile.TemporaryFile() as tmp:
    h=hashlib.sha256();total=0
    for part in pack['parts']:
     p=safe(part['path'])
     if p.stat().st_size!=part['bytes'] or sha(p)!=part['sha256']:raise SystemExit('Corrupt part: '+part['path'])
     with p.open('rb') as src:
      for b in iter(lambda:src.read(1024*1024),b''):tmp.write(b);h.update(b);total+=len(b)
    if h.hexdigest()!=pack['archive_sha256'] or total!=pack['archive_bytes']:raise SystemExit('Archive mismatch')
    tmp.seek(0)
    with zipfile.ZipFile(tmp) as z:
     for info in z.infolist():
      if info.filename not in by_path:raise SystemExit('Unexpected archive entry: '+info.filename)
      dest=safe(info.filename)
      if dest.exists():continue
      dest.parent.mkdir(parents=True,exist_ok=True)
      with z.open(info) as src,dest.open('xb') as out:shutil.copyfileobj(src,out)
  for row in files:
   if 'alias' not in row:continue
   dest=safe(row['path']);src=safe(row['alias'])
   if not dest.exists():dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dest)
 bad=[r['path'] for r in files if not safe(r['path']).exists() or safe(r['path']).stat().st_size!=r['bytes'] or sha(safe(r['path']))!=r['sha256']]
 print(json.dumps({'passed':not bad,'groups':groups,'files':len(files),'failed':bad},ensure_ascii=False));raise SystemExit(1 if bad else 0)
if __name__=='__main__':main()
