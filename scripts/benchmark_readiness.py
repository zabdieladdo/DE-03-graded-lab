"""E062: matched local export-only and verified publication benchmarks (Linux/WSL)."""
import argparse
import csv
import hashlib
import json
import os
import resource
import statistics
import subprocess
import sys
import tempfile
from datetime import date
from pathlib import Path
from time import perf_counter

ROOT = Path(__file__).resolve().parents[1]
GEN = ROOT / 'scripts/generate_monday_report.py'
EXPECTED = {'customer_summary':40420,'monthly_running':485040,'top100':100,
            'ranking_metadata':1,'reconciliation':1,'period_metadata':1}
FROZEN = {'scripts/generate_monday_report.py':'73ca6372e62d42ab85a6fad5a2cd3deb9ef9afad87504f4c2ce7cad34eba4e73',
          'config/readiness_policy.json':'85e0cbddef2959deefac8544a59fc2f4012187fa53ea05167fd600c84c198d97',
          'sql/07_improvement/01_reference_customers.sql':'c14cd861da632ff9c249a300ec6853f95b864ba9db4f8e24301a90a7ef5d91a4',
          'sql/07_improvement/02_reference_exceptions.sql':'1f579da5ebb2303e9b443fc971d56c0e1891ada6d07a32151deea2686f28618b'}

# Calculate a SHA-256 fingerprint for traceability.
def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

# Reject invalid state before proceeding.
def require(ok, msg):
    if not ok: raise RuntimeError(msg)

# Read peak resident memory for this Python process.
def rss():
    return resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024

# Generate baseline CSVs without publication verification.
def export_only(cutoff):
    import psycopg2
    from psycopg2.extras import RealDictCursor
    from generate_monday_report import REPORTS
    start = perf_counter()
    actual = {}
    with tempfile.TemporaryDirectory(prefix='.e062-export-',dir=ROOT/'generated') as tmp:
        out = Path(tmp)
        conn = psycopg2.connect(os.environ['DATABASE_URL'],connect_timeout=10,application_name='de03_e062_export')
        try:
            conn.set_session(isolation_level='REPEATABLE READ',readonly=True,autocommit=False)
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("SET LOCAL statement_timeout='120s'")
                cur.execute("SET LOCAL lock_timeout='5s'")
                cur.execute("SELECT current_database() AS db, current_setting('transaction_isolation') AS isolation, current_setting('transaction_read_only') AS read_only")
                require(dict(cur.fetchone())==dict(db='kloudkart_lab',isolation='repeatable read',read_only='on'),'Wrong environment')
                t=perf_counter()
                for name,(fn,order) in REPORTS.items():
                    cur.execute(f'SELECT * FROM public.{fn}(%s) ORDER BY {order}',(cutoff,))
                    fields=[d.name for d in cur.description]; rows=[dict(r) for r in cur.fetchall()]; actual[name]=rows
                    with (out/f'{name}.csv').open('w',newline='',encoding='utf-8') as f:
                        writer=csv.DictWriter(f,fieldnames=fields); writer.writeheader(); writer.writerows(rows)
                report=perf_counter()-t
                conn.rollback()
        finally: conn.close()
        require({k:len(v) for k,v in actual.items()}==EXPECTED,'Unexpected row counts')
        hashes={p.name:digest(p) for p in out.iterdir()}
        size=sum(p.stat().st_size for p in out.iterdir())
        elapsed=perf_counter()-start
    print('EXPORT_RESULT '+json.dumps(dict(report_seconds=report,elapsed_seconds=elapsed,peak_rss_mib=rss(),hashes=hashes,bytes=size)))


# Run one benchmark child and collect its timing output.
def run_child(cmd):
    start=perf_counter()
    p=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=1200)
    wall=perf_counter()-start
    require(p.returncode==0,f'Child exit {p.returncode}; benchmark stopped (raw child output withheld)')
    return p.stdout.splitlines(),wall


# Run the verified publication path and inspect its package.
def full(cutoff):
    # Execute the unchanged generator in its own interpreter, then measure that process RSS.
    wrapper="import runpy,resource,sys; path=sys.argv.pop(1); sys.path.insert(0,str(__import__('pathlib').Path(path).parent));\ntry: runpy.run_path(path,run_name='__main__')\nfinally: print('PEAK_RSS_MIB',resource.getrusage(resource.RUSAGE_SELF).ru_maxrss/1024)"
    lines,wall=run_child([sys.executable,'-c',wrapper,str(GEN),'--as-of',str(cutoff)])
    run_id=next(x.split()[1] for x in lines if x.startswith('Run: '))
    import uuid
    require(str(uuid.UUID(run_id))==run_id,'Invalid run ID')
    out=ROOT/'generated'/run_id
    m=json.loads((out/'manifest.json').read_text())
    require(m['overall_status']=='WARN' and m['as_of_date']==str(cutoff) and m['run_id']==run_id,'Unexpected readiness result')
    require(m['policy_sha256']==FROZEN['config/readiness_policy.json'],'Policy changed')
    require(m['implementation_checksums']=={k:v for k,v in FROZEN.items() if k!='config/readiness_policy.json'},'Implementation changed')
    hashes=m['output_checksums']; require(set(hashes)=={k+'.csv' for k in EXPECTED}|{'readiness.json'},'Wrong output coverage')
    require(all(digest(out/k)==v for k,v in hashes.items()),'Checksum mismatch')
    return dict(run_id=run_id,wall_seconds=wall,peak_rss_mib=float(next(x.split()[1] for x in lines if x.startswith('PEAK_RSS_MIB '))),hashes={k:v for k,v in hashes.items() if k.endswith('.csv')},**{k:m[k] for k in ('report_seconds','reference_seconds','evaluation_seconds','elapsed_seconds')})


# Coordinate the command-line workflow and its validation.
def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--export-worker',action='store_true'); ap.add_argument('--pairs',type=int,default=3); a=ap.parse_args()
    cutoff=date(2026,8,31)
    if a.export_worker: export_only(cutoff); return
    require(1<=a.pairs<=10,'Pairs must be 1..10')
    require(os.environ.get('DATABASE_URL'),'DATABASE_URL not set')
    require(all(digest(ROOT/k)==v for k,v in FROZEN.items()),'Frozen implementation or policy mismatch')
    (ROOT/'generated').mkdir(exist_ok=True)
    require(subprocess.run(['git','check-ignore','-q','generated/test.csv'],cwd=ROOT).returncode==0,'generated/ must be ignored')
    print('E062 cutoff',cutoff,'pairs',a.pairs,'alternating order; no explicit warmup or cache reset',flush=True)
    results=[]; baseline=None
    for i in range(a.pairs):
        pair={}
        for mode in (('export','full') if i%2==0 else ('full','export')):
            if mode=='export':
                lines,wall=run_child([sys.executable,str(Path(__file__).resolve()),'--export-worker'])
                r=json.loads(next(x.removeprefix('EXPORT_RESULT ') for x in lines if x.startswith('EXPORT_RESULT '))); r['wall_seconds']=wall
            else: r=full(cutoff)
            if baseline is None: baseline=r['hashes']
            require(r['hashes']==baseline,'CSV output changed between runs; investigate before comparing timings')
            pair[mode]=r
            print('PAIR',i+1,mode,json.dumps({k:v for k,v in r.items() if k!='hashes'}),flush=True)
        results.append(pair)
    for mode in ('export','full'):
        for metric in ('wall_seconds','report_seconds','peak_rss_mib'):
            values=[p[mode][metric] for p in results]
            print(f'{mode} {metric}: min={min(values):.3f} median={statistics.median(values):.3f} max={max(values):.3f}')
    for metric,values in [('paired_wall_delta_seconds',[p['full']['wall_seconds']-p['export']['wall_seconds'] for p in results]),('reference_plus_evaluation_seconds',[p['full']['reference_seconds']+p['full']['evaluation_seconds'] for p in results])]:
        print(f'{metric}: min={min(values):.3f} median={statistics.median(values):.3f} max={max(values):.3f}')
    print('PASS: All six CSV hashes identical across all runs; full packages verified; export-only temporary files removed')

if __name__=='__main__':
    try: main()
    except Exception as exc:
        print('ERROR:',type(exc).__name__,str(exc) if isinstance(exc,RuntimeError) else '(details withheld)',file=sys.stderr)
        sys.exit(1)
