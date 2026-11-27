"""E060b: generate and independently validate the six Monday report outputs.
Local lab only. Output contains customer names; keep generated/ private.
"""
import argparse
import csv
import hashlib
import json
import os
import subprocess
import sys
import uuid
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal as D, ROUND_HALF_UP
from itertools import zip_longest
from pathlib import Path
from time import perf_counter

ROOT = Path(__file__).resolve().parents[1]
SQL = ROOT / 'sql/07_improvement'
DISCLOSURE = ('Source completeness and real-world financial accuracy are not independently verified. '
              'Zero recorded spending does not prove absence of business activity. '
              'Historical order status and customer population reflect the current extract. Currency is unconfirmed.')
REPORTS = {
    'customer_summary': ('customer_spending_summary', 'customer_id'),
    'monthly_running': ('customer_monthly_running_spending', 'customer_id, order_month'),
    'top100': ('customer_top100', 'ranking_position'),
    'ranking_metadata': ('customer_top100_metadata', 'as_of_date'),
    'reconciliation': ('spending_reconciliation', 'as_of_date'),
    'period_metadata': ('monthly_reporting_metadata', 'as_of_date'),
}
REQUIRED = {f'R{i:02}' for i in range(1, 8)} | {'R09', 'R10', 'R11', 'R12', 'D01'}


# Reject invalid state before proceeding.
def require(ok, message):
    if not ok:
        raise ValueError(message)


# Calculate a SHA-256 fingerprint for traceability.
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


# Build a structured readiness result with an explicit kind and status.
def check(cid, status, observed, caveat, threshold=None, count=None, value=None, kind='CHECK'):
    return dict(check_id=cid, kind=kind, status=status, observed=observed, threshold=threshold,
                affected_count=count, affected_value=value, caveat=caveat,
                recommended_action={'FAIL':'Hold and correct report', 'ERROR':'Hold and restore verification',
                                    'WARN':'Review and disclose before release', 'PASS':'Normal review', None:'Disclose' }[status])


# Apply required-entry checks and severity precedence.
def overall(checks):
    ids = [r['check_id'] for r in checks]
    if len(ids) != len(set(ids)) or set(ids) != REQUIRED:
        return 'ERROR'
    for r in checks:
        if r['check_id'] == 'D01':
            if r['kind'] != 'DISCLOSURE' or r['caveat'] != DISCLOSURE or r['status'] is not None:
                return 'ERROR'
        elif r['check_id'] in {'R09','R10','R11','R12'}:
            if r['kind'] != 'INFO' or r['status'] is not None:
                return 'ERROR'
        elif r['kind'] != 'CHECK' or r['status'] not in {'PASS','WARN','FAIL','ERROR'}:
            return 'ERROR'
    return next(s for s in ('ERROR','FAIL','WARN','PASS') if s == 'PASS' or any(r['status']==s for r in checks))


# Validate the policy before evaluating report data.
def policy_validate(p):
    require(p['comparison']=='strict_greater_than' and p['combination']=='OR', 'Invalid policy logic')
    require(p['policy_approval_status']=='proposed', 'Only proposed lab policy supported')
    require(set(p['checks'])=={'R05','R06','R07'}, 'Missing policy checks')
    bases = {'R05':'unattributed_recorded_value','R06':'sum_absolute_header_item_gap','R07':'incomplete_order_recorded_header_value'}
    for cid, t in p['checks'].items():
        require(t['value_basis']==bases[cid], 'Wrong value basis')
        for k in ('count_share_pct','value_share_pct','absolute_limit'):
            if k=='absolute_limit' and t[k] is None:
                continue
            v=D(t[k]); require(v.is_finite() and v>=0 and (k=='absolute_limit' or v<=100), 'Invalid threshold')
        require(t['absolute_limit'] is None or p['currency'], 'Absolute limit requires explicit currency/unit')


# Compare exact relative and optional absolute limits.
def materiality(cid, n, value, total_n, total_value, threshold, description):
    require(0<=n<=total_n and value>=0 and total_value>=0, 'Invalid exception measures')
    require(total_n or not n, 'Nonzero count with zero population')
    # Zero recorded spending can coexist with nonzero item gaps. Relative monetary
    # share is undefined; hold for review rather than silently treating it as zero.
    cp = D(n)*100/total_n if total_n else None
    vp = value*100/total_value if total_value else None
    exceeded = []
    if total_n and D(n)*100 > D(threshold['count_share_pct'])*total_n: exceeded.append('count_share_pct')
    if total_value and value*100 > D(threshold['value_share_pct'])*total_value: exceeded.append('value_share_pct')
    if not total_value and value: exceeded.append('undefined_nonzero_value_share')
    if threshold['absolute_limit'] is not None and value>D(threshold['absolute_limit']): exceeded.append('absolute_limit')
    fmt=lambda v: 'not applicable' if v is None else f'{v:.4f}%'
    caveat=f'{description}: {n:,} of {total_n:,} eligible orders ({fmt(cp)}); {value:,.2f} recorded monetary units ({fmt(vp)} of eligible recorded spending).'
    return check(cid,'WARN' if exceeded else 'PASS',dict(count_share_pct=cp,value_share_pct=vp,exceeded=exceeded),caveat,threshold,n,value)


# Compare ordered report rows against independent expected values.
def compare(actual, expected, fields=None):
    """Count positional differences, including missing/extra rows; inputs ordered by key."""
    bad=0
    for a,e in zip_longest(actual,expected):
        if a is None or e is None or (fields is None and a!=e) or (fields is not None and any(a.get(k)!=e[k] for k in fields)):
            bad+=1
    return bad


# Construct expected report outputs from the independent reference.
def expected_reports(ref, ex, cutoff):
    end=cutoff+timedelta(days=1)
    partial=end.day!=1
    start=date(cutoff.year,1,1) if cutoff.month==12 else date(cutoff.year-1,cutoff.month+1,1)
    common=dict(as_of_date=cutoff)
    summary=[]; candidates=[]
    for r in ref:
        summary.append(dict(**common,customer_id=r['customer_id'],full_name=r['full_name'],total_spent=r['history_amount'],order_count=r['history_count'],first_order_date=r['first_order_date'],last_order_date=r['last_order_date']))
        w=sum(r['monthly_amounts'],D(0)); n=sum(r['monthly_counts'])
        if w>0: candidates.append((w,r['customer_id'],n,r))
    # Yield the expected monthly and cumulative rows.
    def monthly():
        for r in ref:
            running=D(0)
            for m,a,n in zip(r['months'],r['monthly_amounts'],r['monthly_counts']):
                running+=a
                yield dict(**common,customer_id=r['customer_id'],order_month=m,monthly_spending=a,monthly_order_count=n,opening_spending=r['opening_amount'],window_cumulative_spending=running,cumulative_since_extract_start=r['opening_amount']+running,is_partial_month=partial and m==cutoff.replace(day=1))
    candidates.sort(key=lambda x:(-x[0],x[1]))
    base=dict(**common,ranking_basis='trailing_12_months',window_start=start,is_partial_month=partial)
    top=[]; last=None; rank=0
    for pos,(w,cid,n,r) in enumerate(candidates[:100],1):
        if w!=last: rank=pos; last=w
        top.append(dict(**base,ranking_position=pos,spending_rank=rank,customer_id=cid,full_name=r['full_name'],ranking_spending=w,ranking_order_count=n,window_spending=w,window_order_count=n,recorded_history_spending=r['history_amount'],recorded_history_order_count=r['history_count']))
    cut=top[-1]['ranking_spending'] if len(top)==100 else None
    ties=sum(w==cut for w,*_ in candidates); selected_ties=sum(r['ranking_spending']==cut for r in top)
    q=sum((w for w,*_ in candidates),D(0)); s=sum((r['ranking_spending'] for r in top),D(0))
    meta=dict(**base,qualifying_customer_count=len(candidates),selected_customer_count=len(top),cutoff_spending=cut,customers_at_cutoff=ties,cutoff_customers_selected=selected_ties,cutoff_customers_excluded=ties-selected_ties,has_excluded_cutoff_ties=ties>selected_ties,qualifying_spending=q,selected_spending=s,remaining_qualifying_spending=q-s,selected_spending_pct=(s*100/q).quantize(D('.0001'),rounding=ROUND_HALF_UP) if q else None,tie_break_policy='Customer ID ascending; arbitrary deterministic tie-breaker')
    recon=dict(**common,**{k:ex[k] for k in ('eligible_orders','eligible_value','attributed_orders','attributed_value','unattributed_orders','unattributed_value')})
    period=dict(**common,window_start=start,window_end_exclusive=datetime.combine(end,datetime.min.time()),month_count=12,is_partial_month=partial)
    return summary,monthly,top,meta,recon,period


# Disclose empty eligible populations without changing technical severity.
def population_info(ex):
    n, value = ex['eligible_orders'], ex['eligible_value']
    require(n != 0 or value == 0, 'Nonzero eligible value with zero eligible orders')
    caveat = ('No eligible orders were found through the selected cutoff. This does not '
              'establish absence of business activity. Review source coverage, cutoff and eligibility rules.'
              if n == 0 else f'{n:,} eligible orders found through the selected cutoff.')
    return check('R12', None, n, caveat, kind='INFO')


# Evaluate report consistency, exceptions and disclosures.
def evaluate(actual, ref, ex, cutoff, policy):
    require(len({r['customer_id'] for r in ref})==len(ref), 'Duplicate reference customer')
    require(all(len(r['months'])==len(r['monthly_amounts'])==len(r['monthly_counts'])==12 and len(set(r['months']))==12 and r['history_amount']==r['opening_amount']+sum(r['monthly_amounts']) and r['history_count']==r['opening_count']+sum(r['monthly_counts']) for r in ref), 'Invalid customer reference')
    summary,monthly,top,meta,recon,period=expected_reports(ref,ex,cutoff)
    ids=compare(actual['customer_summary'],summary,['customer_id'])
    s=compare(actual['customer_summary'],summary)
    r=compare(actual['reconciliation'],[recon])
    identities=(ex['eligible_orders']==ex['attributed_orders']+ex['unattributed_orders'] and ex['eligible_value']==ex['attributed_value']+ex['unattributed_value'] and sum(x['history_count'] for x in ref)==ex['attributed_orders'] and sum(x['history_amount'] for x in ref)==ex['attributed_value'] and not ex['null_header_amount_orders'])
    m=compare(actual['monthly_running'],monthly())
    p=compare(actual['period_metadata'],[period],list(period))
    if len(actual['period_metadata'])==1 and not actual['period_metadata'][0].get('coverage_warning'): p+=1
    t=compare(actual['top100'],top); tm=compare(actual['ranking_metadata'],[meta])
    checks=[]
    for cid,bad,desc in [('R01',ids,'Customer population'),('R02',s+r+int(not identities),'Customer summary and financial reconciliation'),('R03',m+p,'Monthly, cumulative and period outputs'),('R04',t+tm,'Ranking and metadata')]:
        checks.append(check(cid,'FAIL' if bad else 'PASS',bad,f'{desc}: {bad:,} comparison differences (positional; not unique affected records).',0))
    for cid,n,v,desc in [('R05','unattributed_orders','unattributed_value','Orders without valid customer attribution; recorded spending'),('R06','mismatch_orders','mismatch_absolute_gap','Complete valuations disagree with checkout totals; absolute differences, not proven loss'),('R07','incomplete_orders','incomplete_recorded_value','Incomplete item valuations; associated checkout value, not missing item value')]:
        checks.append(materiality(cid,ex[n],ex[v],ex['eligible_orders'],ex['eligible_value'],policy['checks'][cid],desc))
    checks.extend([check('R09',None,period['is_partial_month'],f"Final month {'is partial' if period['is_partial_month'] else 'is complete'} through {cutoff}; no month-over-month comparison is generated.",kind='INFO'),
        check('R10',None,{k:ex[k] for k in ('missing_date_count','after_cutoff_count','missing_date_value','after_cutoff_value')},f"Completed-status orders excluded: {ex['missing_date_count']} missing dates, {ex['after_cutoff_count']} after cutoff; after-cutoff records are not automatically errors.",kind='INFO'),
        check('R11',None,ex['shared_email_groups'],f"{ex['shared_email_groups']} shared email groups across {ex['shared_email_accounts']} accounts; not proof of duplicate people.",kind='INFO'),population_info(ex),check('D01',None,None,DISCLOSURE,kind='DISCLOSURE')])
    return checks


# Serialize structured metadata to disk.
def write_json(path,obj):
    path.write_text(json.dumps(obj,default=str,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')


# Coordinate the command-line workflow and its validation.
def main():
    import psycopg2
    from psycopg2.extras import RealDictCursor
    ap=argparse.ArgumentParser(); ap.add_argument('--as-of',required=True,type=date.fromisoformat); args=ap.parse_args()
    started=perf_counter(); run_id=str(uuid.uuid4()); out=ROOT/'generated'/run_id; out.mkdir(parents=True,mode=0o700)
    os.chmod(out,0o700)
    manifest=dict(run_id=run_id,as_of_date=args.as_of,generated_at=datetime.now(timezone.utc),overall_status='ERROR',publication_action='HOLD',output_checksums={})
    conn=None
    try:
        policy_path=ROOT/'config/readiness_policy.json'; policy=json.loads(policy_path.read_text()); policy_validate(policy)
        manifest.update(policy_version=policy['policy_version'],policy_approval_status=policy['policy_approval_status'],policy_sha256=digest(policy_path),policy_review_date=policy['review_date'])
        manifest['git_commit']=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
        manifest['git_dirty']=bool(subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True).strip())
        manifest['implementation_checksums']={str(p.relative_to(ROOT)):digest(p) for p in [Path(__file__).resolve(),*sorted(SQL.glob('0[12]_reference_*.sql'))]}
        conn=psycopg2.connect(os.environ['DATABASE_URL'],connect_timeout=10,application_name='de03_readiness')
        conn.set_session(isolation_level='REPEATABLE READ',readonly=True,autocommit=False)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SET LOCAL statement_timeout='120s'"); cur.execute("SET LOCAL lock_timeout='5s'")
            cur.execute("SELECT current_database() AS db, pg_current_snapshot()::text AS snapshot, current_setting('transaction_isolation') AS isolation, current_setting('transaction_read_only') AS read_only")
            env=dict(cur.fetchone()); require(env['db']=='kloudkart_lab' and env['isolation']=='repeatable read' and env['read_only']=='on','Wrong environment'); manifest.update(env)
            print('Environment:',env); actual={}; t=perf_counter()
            for name,(fn,order) in REPORTS.items():
                cur.execute(f'SELECT * FROM public.{fn}(%s) ORDER BY {order}',(args.as_of,)); fields=[d.name for d in cur.description]; rows=[dict(r) for r in cur.fetchall()]; actual[name]=rows
                with (out/f'{name}.csv').open('w',newline='',encoding='utf-8') as f:
                    writer=csv.DictWriter(f,fieldnames=fields); writer.writeheader(); writer.writerows(rows)
                print(f'{name}: {len(rows)} rows')
            manifest['report_seconds']=perf_counter()-t; t=perf_counter()
            cur.execute((SQL/'01_reference_customers.sql').read_text(),{'as_of_date':args.as_of}); ref=[dict(r) for r in cur.fetchall()]
            cur.execute((SQL/'02_reference_exceptions.sql').read_text(),{'as_of_date':args.as_of}); ex=dict(cur.fetchone()); require(cur.fetchone() is None,'Multiple exception summaries')
            manifest['reference_seconds']=perf_counter()-t; t=perf_counter()
            checks=evaluate(actual,ref,ex,args.as_of,policy); status=overall(checks); manifest['evaluation_seconds']=perf_counter()-t
            conn.rollback()
        write_json(out/'readiness.json',dict(run_id=run_id,as_of_date=args.as_of,policy=policy,checks=checks,overall_status=status))
        manifest['output_checksums']={p.name:digest(p) for p in sorted(out.iterdir()) if p.is_file()}
        manifest['overall_status']=status; manifest['publication_action']={'PASS':'NORMAL REVIEW','WARN':'REVIEW AND DISCLOSE','FAIL':'HOLD','ERROR':'HOLD'}[status]
        for r in checks: print(r['check_id'],r['status'] or r['kind'],r['caveat'])
    except Exception as e:
        # Avoid printing credentials or raw customer records in evidence.
        manifest['overall_status']='ERROR'; manifest['publication_action']='HOLD'; manifest['error_type']=type(e).__name__; print('ERROR:',type(e).__name__, 'SQLSTATE:',getattr(e,'pgcode',None),file=sys.stderr)
    finally:
        if conn is not None: conn.close()
        manifest['elapsed_seconds']=perf_counter()-started; write_json(out/'manifest.json',manifest)
        print('Run:',run_id,'Status:',manifest['overall_status'],'Action:',manifest['publication_action']); print('Manifest:',out/'manifest.json'); print('Timings:',{k:v for k,v in manifest.items() if k.endswith('_seconds')})
    return {'PASS':0,'WARN':0,'FAIL':2,'ERROR':3}[manifest['overall_status']]

if __name__=='__main__': sys.exit(main())
