"""FlowMD local backend.

Run: python3 backend.py
Then open http://127.0.0.1:8000/import.html
HealthKit XML is parsed with iterparse and never held in memory whole.
"""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs
from pathlib import Path
from datetime import datetime, date
import sqlite3, json, os, re, threading, tempfile, xml.etree.ElementTree as ET

ROOT = Path(__file__).parent
DB = ROOT / "flowmd.db"
SUPPORTED = {
    "HKQuantityTypeIdentifierHeartRate": "heart_rate",
    "HKQuantityTypeIdentifierRestingHeartRate": "resting_heart_rate",
    "HKQuantityTypeIdentifierHeartRateVariabilitySDNN": "hrv",
    "HKQuantityTypeIdentifierStepCount": "steps",
    "HKQuantityTypeIdentifierAppleExerciseTime": "exercise_minutes",
    "HKQuantityTypeIdentifierActiveEnergyBurned": "active_energy",
    "HKQuantityTypeIdentifierWalkingSpeed": "walking_speed",
    "HKQuantityTypeIdentifierWalkingAsymmetryPercentage": "walking_asymmetry",
    "HKQuantityTypeIdentifierRespiratoryRate": "respiratory_rate",
    "HKQuantityTypeIdentifierVO2Max": "vo2_max",
}
METRIC_UNITS = {"heart_rate":"count/min", "resting_heart_rate":"count/min", "hrv":"ms", "steps":"count"}

def db():
    c = sqlite3.connect(DB); c.row_factory = sqlite3.Row
    c.execute("PRAGMA journal_mode=WAL"); return c

def init():
    c=db(); c.executescript("""
    CREATE TABLE IF NOT EXISTS imports(id INTEGER PRIMARY KEY, filename TEXT, started_at TEXT, finished_at TEXT, records INTEGER, status TEXT, error TEXT);
    CREATE TABLE IF NOT EXISTS measurements(id INTEGER PRIMARY KEY, import_id INTEGER, metric TEXT, value REAL, unit TEXT, start_time TEXT, day TEXT, source TEXT);
    CREATE INDEX IF NOT EXISTS ix_measurements_metric_day ON measurements(metric,day);
    CREATE TABLE IF NOT EXISTS patients(id TEXT PRIMARY KEY, name TEXT, mrn TEXT, age INTEGER, sex TEXT, updated_at TEXT);
    INSERT OR IGNORE INTO patients VALUES('demo-maya','Maya Chen','MRN-20481',42,'Female',datetime('now'));
    """); c.commit(); c.close()

def parse_date(s):
    return (s or "")[:10]

def ingest(path, filename):
    c=db(); started=datetime.utcnow().isoformat(); cur=c.execute("INSERT INTO imports(filename,started_at,status,records) VALUES(?,?,?,0)",(filename,started,'processing')); iid=cur.lastrowid; c.commit(); n=0
    try:
        batch=[]
        for _, el in ET.iterparse(path, events=("end",)):
            if el.tag == "Record" and el.attrib.get("type") in SUPPORTED:
                a=el.attrib; metric=SUPPORTED[a["type"]]
                try: value=float(a.get("value", "nan"))
                except ValueError: value=None
                if value is not None and value == value:
                    ts=a.get("startDate",""); batch.append((iid,metric,value,a.get("unit",METRIC_UNITS.get(metric,"")),ts,parse_date(ts),a.get("sourceName","Apple Health"))); n+=1
                if len(batch)>=5000:
                    c.executemany("INSERT INTO measurements(import_id,metric,value,unit,start_time,day,source) VALUES(?,?,?,?,?,?,?)",batch); c.commit(); batch.clear()
            el.clear()
        if batch: c.executemany("INSERT INTO measurements(import_id,metric,value,unit,start_time,day,source) VALUES(?,?,?,?,?,?,?)",batch)
        c.execute("UPDATE imports SET finished_at=?,records=?,status='complete' WHERE id=?",(datetime.utcnow().isoformat(),n,iid)); c.commit()
        return {"id":iid,"filename":filename,"records":n,"status":"complete"}
    except Exception as e:
        c.execute("UPDATE imports SET finished_at=?,records=?,status='error',error=? WHERE id=?",(datetime.utcnow().isoformat(),n,str(e),iid)); c.commit(); raise
    finally: c.close()

def summary(metric=None, days=30):
    c=db(); where="WHERE day >= date('now', ?)"; args=(f'-{int(days)} days',)
    if metric: where += " AND metric=?"; args += (metric,)
    rows=c.execute(f"SELECT metric,day,AVG(value) avg,MIN(value) min,MAX(value) max,COUNT(*) samples FROM measurements {where} GROUP BY metric,day ORDER BY day",args).fetchall(); c.close()
    return [dict(r) for r in rows]

def insights():
    c=db(); result=[]
    for metric in ("resting_heart_rate","heart_rate","steps","walking_speed","respiratory_rate"):
        r=c.execute("SELECT AVG(value) avg FROM measurements WHERE metric=? AND day >= date('now','-30 days')",(metric,)).fetchone()
        old=c.execute("SELECT AVG(value) avg FROM measurements WHERE metric=? AND day BETWEEN date('now','-60 days') AND date('now','-31 days')",(metric,)).fetchone()
        if r and old and r[0] and old[0]:
            pct=(r[0]-old[0])/old[0]*100
            if abs(pct)>=8: result.append({"metric":metric,"current":round(r[0],2),"baseline":round(old[0],2),"change_pct":round(pct,1),"confidence":"high" if abs(pct)>=15 else "medium"})
    c.close(); return result

class Handler(BaseHTTPRequestHandler):
    def send_json(self, obj, code=200):
        raw=json.dumps(obj).encode(); self.send_response(code); self.send_header('Content-Type','application/json'); self.send_header('Content-Length',str(len(raw))); self.end_headers(); self.wfile.write(raw)
    def do_GET(self):
        u=urlparse(self.path); p=u.path
        if p.startswith('/api/'):
            if p=='/api/health': return self.send_json({'ok':True,'service':'flowmd-backend'})
            if p=='/api/imports':
                c=db(); rows=[dict(x) for x in c.execute('SELECT * FROM imports ORDER BY id DESC LIMIT 20')]; c.close(); return self.send_json(rows)
            if p=='/api/metrics': return self.send_json(summary(parse_qs(u.query).get('metric',[None])[0], parse_qs(u.query).get('days',[30])[0]))
            if p=='/api/insights': return self.send_json(insights())
            if p=='/api/patients':
                c=db(); rows=[dict(x) for x in c.execute('SELECT * FROM patients')]; c.close(); return self.send_json(rows)
            return self.send_json({'error':'not found'},404)
        file=(ROOT / (p.lstrip('/') or 'index.html')).resolve()
        if ROOT not in file.parents and file != ROOT: return self.send_error(403)
        if file.exists() and file.is_file():
            body=file.read_bytes()
            if file.suffix=='.html':
                extras=''
                if file.name=='import.html': extras='<script src="/import-api.js"></script>'
                extras+='<script src="/nav.js"></script>'
                body=body.replace(b'</body>',extras.encode()+b'</body>')
            self.send_response(200); self.send_header('Content-Type','text/html' if file.suffix=='.html' else 'text/plain'); self.send_header('Content-Length',str(len(body))); self.end_headers(); self.wfile.write(body); return
        self.send_error(404)
    def do_POST(self):
        if self.path != '/api/import': return self.send_json({'error':'not found'},404)
        length=int(self.headers.get('Content-Length','0')); name=self.headers.get('X-Filename','health_export.xml'); tmp=tempfile.NamedTemporaryFile(delete=False,suffix='.xml')
        try:
            remaining=length
            while remaining: chunk=self.rfile.read(min(1024*1024,remaining)); tmp.write(chunk); remaining-=len(chunk)
            tmp.close(); result=ingest(tmp.name,name); return self.send_json(result)
        except Exception as e: return self.send_json({'error':str(e)},400)
        finally:
            try: os.unlink(tmp.name)
            except OSError: pass
    def log_message(self, *args): pass

if __name__=='__main__':
    init(); port=int(os.environ.get('PORT','8000')); print(f'FlowMD running on port {port}'); ThreadingHTTPServer(('0.0.0.0',port),Handler).serve_forever()
