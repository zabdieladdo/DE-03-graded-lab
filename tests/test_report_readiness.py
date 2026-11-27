"""E061 isolated evaluator tests. No database access or production writes."""
import copy
import json
import os
import sys
import tempfile
import types
import unittest
from datetime import date, datetime
from decimal import Decimal as D
from pathlib import Path
from unittest.mock import patch, MagicMock
from contextlib import redirect_stdout, redirect_stderr
from io import StringIO

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import generate_monday_report as g

POLICY = json.loads((ROOT / 'config/readiness_policy.json').read_text())
CUTOFF = date(2026, 8, 31)


# Construct independent synthetic input and expected report rows.
def fixture():
    # Hand-built expected report: one opening order of 20, one window order
    # of 100, one inactive customer. No call to expected_reports to build actual.
    months = [date(2025 if m >= 9 else 2026, m, 1) for m in [9,10,11,12,1,2,3,4,5,6,7,8]]
    first, last = datetime(2025,8,1), datetime(2026,8,1)
    ref = [dict(customer_id=1, full_name='Synthetic A', history_count=2, history_amount=D(120), first_order_date=first,last_order_date=last,opening_amount=D(20),opening_count=1,months=months,monthly_amounts=[D(0)]*11+[D(100)],monthly_counts=[0]*11+[1]),
           dict(customer_id=2, full_name='Synthetic B',history_count=0,history_amount=D(0),first_order_date=None,last_order_date=None,opening_amount=D(0),opening_count=0,months=months,monthly_amounts=[D(0)]*12,monthly_counts=[0]*12)]
    ex = dict(eligible_orders=2,eligible_value=D(120),attributed_orders=2,attributed_value=D(120),unattributed_orders=0,unattributed_value=D(0),mismatch_orders=0,mismatch_absolute_gap=D(0),incomplete_orders=0,incomplete_recorded_value=D(0),null_header_amount_orders=0,missing_date_count=0,after_cutoff_count=0,missing_date_value=D(0),after_cutoff_value=D(0),shared_email_groups=0,shared_email_accounts=0)
    common = dict(as_of_date=CUTOFF)
    summary = [dict(**common,customer_id=1,full_name='Synthetic A',total_spent=D(120),order_count=2,first_order_date=first,last_order_date=last),dict(**common,customer_id=2,full_name='Synthetic B',total_spent=D(0),order_count=0,first_order_date=None,last_order_date=None)]
    monthly=[]
    for cid in (1,2):
        for m in months:
            a=D(100) if cid==1 and m.month==8 else D(0)
            opening=D(20) if cid==1 else D(0)
            monthly.append(dict(**common,customer_id=cid,order_month=m,monthly_spending=a,monthly_order_count=int(a>0),opening_spending=opening,window_cumulative_spending=a,cumulative_since_extract_start=opening+a,is_partial_month=False))
    base=dict(**common,ranking_basis='trailing_12_months',window_start=date(2025,9,1),is_partial_month=False)
    top=[dict(**base,ranking_position=1,spending_rank=1,customer_id=1,full_name='Synthetic A',ranking_spending=D(100),ranking_order_count=1,window_spending=D(100),window_order_count=1,recorded_history_spending=D(120),recorded_history_order_count=2)]
    meta=dict(**base,qualifying_customer_count=1,selected_customer_count=1,cutoff_spending=None,customers_at_cutoff=0,cutoff_customers_selected=0,cutoff_customers_excluded=0,has_excluded_cutoff_ties=False,qualifying_spending=D(100),selected_spending=D(100),remaining_qualifying_spending=D(0),selected_spending_pct=D('100.0000'),tie_break_policy='Customer ID ascending; arbitrary deterministic tie-breaker')
    recon=dict(**common,**{k:ex[k] for k in ('eligible_orders','eligible_value','attributed_orders','attributed_value','unattributed_orders','unattributed_value')})
    period=dict(**common,window_start=date(2025,9,1),window_end_exclusive=datetime(2026,9,1),month_count=12,is_partial_month=False,coverage_warning='Synthetic coverage limitation')
    return dict(customer_summary=summary,monthly_running=monthly,top100=top,ranking_metadata=[meta],reconciliation=[recon],period_metadata=[period]),ref,ex

class Readiness(unittest.TestCase):
    # Reset synthetic data and policy for each test.
    def setUp(self):
        self.a,self.r,self.e=fixture(); self.p=copy.deepcopy(POLICY)
    # Evaluate the current synthetic fixture.
    def checks(self):
        return g.evaluate(self.a,self.r,self.e,CUTOFF,self.p)
    # Assert the expected status for one readiness check.
    def expect(self,cid,status):
        checks=self.checks(); self.assertEqual(next(x['status'] for x in checks if x['check_id']==cid),status); self.assertEqual(g.overall(checks),status)
    # Verify pass.
    def test_01_pass(self):
        g.policy_validate(self.p); self.assertEqual(g.overall(self.checks()),'PASS')
    # Verify duplicate.
    def test_02_duplicate(self):
        self.a['customer_summary'].insert(0,copy.deepcopy(self.a['customer_summary'][0])); self.expect('R01','FAIL')
    # Verify missing.
    def test_03_missing(self):
        self.a['customer_summary'].pop(); self.expect('R01','FAIL')
    # Verify summary money.
    def test_04_summary_money(self):
        self.a['customer_summary'][0]['total_spent']+=D('.01'); self.expect('R02','FAIL')
    # Verify reconciliation.
    def test_05_reconciliation(self):
        self.a['reconciliation'][0]['eligible_value']+=D('.01'); self.expect('R02','FAIL')
    # Verify monthly.
    def test_06_monthly(self):
        self.a['monthly_running'][11]['monthly_spending']+=D('.01'); self.expect('R03','FAIL')
    # Verify running.
    def test_07_running(self):
        self.a['monthly_running'][11]['window_cumulative_spending']+=D('.01'); self.expect('R03','FAIL')
    # Verify rank.
    def test_08_rank(self):
        self.a['top100'][0]['spending_rank']=2; self.expect('R04','FAIL')
    # Verify rank metadata.
    def test_09_rank_metadata(self):
        self.a['ranking_metadata'][0]['selected_spending']+=D('.01'); self.expect('R04','FAIL')
    # Verify attribution.
    def test_10_attribution(self):
        self.e.update(eligible_orders=3,eligible_value=D(130),unattributed_orders=1,unattributed_value=D(10)); self.a['reconciliation'][0].update(eligible_orders=3,eligible_value=D(130),unattributed_orders=1,unattributed_value=D(10)); self.expect('R05','WARN')
    # Verify mismatch.
    def test_11_mismatch(self):
        self.e.update(mismatch_orders=1,mismatch_absolute_gap=D(2)); self.expect('R06','WARN')
    # Verify incomplete.
    def test_12_incomplete(self):
        self.e.update(incomplete_orders=1,incomplete_recorded_value=D(20)); self.expect('R07','WARN')
    # Exercise materiality with controlled synthetic limits.
    def material(self,n,v,absolute=None,total_n=1000,total_v=10000):
        t=copy.deepcopy(self.p['checks']['R05']); t['absolute_limit']=absolute
        return g.materiality('R05',n,D(v),total_n,D(total_v),t,'Synthetic exception')
    # Verify count only.
    def test_13_count_only(self):
        r=self.material(11,10); self.assertEqual(r['status'],'WARN'); self.assertEqual(r['observed']['exceeded'],['count_share_pct'])
    # Verify value only.
    def test_14_value_only(self):
        r=self.material(1,101); self.assertEqual(r['status'],'WARN'); self.assertEqual(r['observed']['exceeded'],['value_share_pct'])
    # Verify absolute only.
    def test_15_absolute_only(self):
        r=self.material(1,51,'50'); self.assertEqual(r['status'],'WARN'); self.assertEqual(r['observed']['exceeded'],['absolute_limit'])
    # Verify equality.
    def test_16_equality(self):
        self.assertEqual(self.material(10,100,'100')['status'],'PASS')
    # Verify below.
    def test_17_below(self):
        r=self.material(1,10,'50'); self.assertEqual(r['status'],'PASS'); self.assertEqual(r['affected_count'],1); self.assertIn('10.00',r['caveat'])
    # Verify disabled absolute.
    def test_18_disabled_absolute(self):
        self.assertEqual(self.material(1,99)['status'],'PASS')
    # Verify multiple limits.
    def test_19_multiple_limits(self):
        self.assertEqual(set(self.material(11,101,'50')['observed']['exceeded']),{'count_share_pct','value_share_pct','absolute_limit'})
    # Verify empty denominator.
    def test_20_empty_denominator(self):
        r=self.material(0,0,total_n=0,total_v=0); self.assertEqual(r['status'],'PASS'); self.assertIsNone(r['observed']['count_share_pct']); self.assertIsNone(r['observed']['value_share_pct'])
    # Verify zero value nonzero gap.
    def test_21_zero_value_nonzero_gap(self):
        self.assertEqual(self.material(1,1,total_v=0)['status'],'WARN')
    # Verify invalid population.
    def test_22_invalid_population(self):
        with self.assertRaises(ValueError): self.material(1,0,total_n=0,total_v=0)
    # Verify missing check.
    def test_23_missing_check(self):
        self.assertEqual(g.overall(self.checks()[1:]),'ERROR')
    # Verify duplicate check.
    def test_24_duplicate_check(self):
        c=self.checks(); self.assertEqual(g.overall(c+[c[0]]),'ERROR')
    # Verify missing disclosure.
    def test_25_missing_disclosure(self):
        self.assertEqual(g.overall([x for x in self.checks() if x['check_id']!='D01']),'ERROR')
    # Verify changed disclosure.
    def test_26_changed_disclosure(self):
        c=self.checks(); c[-1]['caveat']=''; self.assertEqual(g.overall(c),'ERROR')
    # Verify precedence.
    def test_27_precedence(self):
        c=self.checks(); c[0]['status']='WARN'; c[1]['status']='FAIL'; self.assertEqual(g.overall(c),'FAIL'); c[2]['status']='ERROR'; self.assertEqual(g.overall(c),'ERROR')
    # Verify invalid policy.
    def test_28_invalid_policy(self):
        for v in ('-1','101','NaN'):
            with self.subTest(v=v):
                p=copy.deepcopy(self.p); p['checks']['R05']['count_share_pct']=v
                with self.assertRaises(ValueError): g.policy_validate(p)
    # Verify absolute currency.
    def test_29_absolute_currency(self):
        self.p['checks']['R05']['absolute_limit']='50'
        with self.assertRaises(ValueError): g.policy_validate(self.p)
        self.p['currency']='SYNTHETIC'; g.policy_validate(self.p)
    # Verify shared email.
    def test_30_shared_email(self):
        self.e.update(shared_email_groups=1,shared_email_accounts=2); c=self.checks(); self.assertEqual(g.overall(c),'PASS'); self.assertEqual(next(x for x in c if x['check_id']=='R11')['kind'],'INFO')
    # Verify partial month.
    def test_31_partial_month(self):
        cutoff=date(2026,8,26)
        # Move synthetic final order earlier; update hand-built actual dates.
        last=datetime(2026,8,1)
        for rows in self.a.values():
            for row in rows:
                row['as_of_date']=cutoff
                if 'is_partial_month' in row: row['is_partial_month']=row.get('order_month',cutoff.replace(day=1))==cutoff.replace(day=1)
        self.a['period_metadata'][0]['window_end_exclusive']=datetime(2026,8,27)
        c=g.evaluate(self.a,self.r,self.e,cutoff,self.p); self.assertEqual(g.overall(c),'PASS'); r=next(x for x in c if x['check_id']=='R09'); self.assertTrue(r['observed']); self.assertIsNone(r['status'])
    # Verify missing period coverage.
    def test_32_missing_period_coverage(self):
        self.a['period_metadata'][0]['coverage_warning']=''; self.expect('R03','FAIL')
    # Verify query error hold.
    def test_33_query_error_hold(self):
        # Mock driver failure on first SQL statement; exercise real main error path.
        with tempfile.TemporaryDirectory() as td:
            root=Path(td); (root/'config').mkdir(); (root/'scripts').mkdir(); (root/'sql').mkdir()
            (root/'config/readiness_policy.json').write_text(json.dumps(self.p)); script=root/'scripts/generate_monday_report.py'; script.write_text('synthetic test placeholder')
            driver=types.ModuleType('psycopg2'); extras=types.ModuleType('psycopg2.extras'); extras.RealDictCursor=object; conn=MagicMock(); driver.connect=MagicMock(return_value=conn)
            conn.cursor.return_value.__enter__.return_value.execute.side_effect=RuntimeError('synthetic query failure')
            with patch.dict(sys.modules,{'psycopg2':driver,'psycopg2.extras':extras}), patch.dict(os.environ,{'DATABASE_URL':'synthetic'}), patch.object(g,'ROOT',root),patch.object(g,'SQL',root/'sql'),patch.object(g,'__file__',str(script)),patch.object(sys,'argv',['test','--as-of','2026-08-31']),patch.object(g.subprocess,'check_output',return_value='synthetic'),redirect_stdout(StringIO()),redirect_stderr(StringIO()):
                self.assertEqual(g.main(),3)
            manifest=json.loads(next((root/'generated').glob('*/manifest.json')).read_text()); self.assertEqual(manifest['overall_status'],'ERROR'); self.assertEqual(manifest['publication_action'],'HOLD'); self.assertEqual(manifest['error_type'],'RuntimeError'); conn.close.assert_called_once()

if __name__=='__main__': unittest.main(verbosity=2)
