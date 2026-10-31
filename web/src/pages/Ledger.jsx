import React, { useEffect, useState } from 'react';
import { api } from '../services/api';
import StatCard from '../components/StatCard';
import RecordControls from '../components/RecordControls';
import { usePagedRecords } from '../hooks/usePagedRecords';
import { downloadCsv } from '../utils/csv';
const load = filters => api.getGlobalLedger(filters);
const columns = [{ key: 'created_at', label: 'Timestamp' }, { key: 'user_email', label: 'User' }, { key: 'reason', label: 'Reason' }, { key: 'campaign_id', label: 'Reference / note' }, { key: 'delta', label: 'Points delta' }];
export default function Ledger() {
  const [reason, setReason] = useState('ALL');
  const [summary, setSummary] = useState(null);
  const [summaryError, setSummaryError] = useState('');
  const records = usePagedRecords(load, { reason });
  async function refreshSummary() {
    try { setSummary(await api.getLedgerSummary()); setSummaryError(''); }
    catch (err) { setSummaryError(err.message); }
  }
  useEffect(() => { refreshSummary(); }, []);
  return <div className="container-main">
    <h1>Points Ledger</h1><p>Append-only record of points earned, spent, and adjusted.</p>
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 16, margin: '20px 0' }}>
      <StatCard label="All-time points credited" value={summary?.credited.toLocaleString() ?? '—'} subtext="Includes rewards and positive adjustments" />
      <StatCard label="All-time points debited" value={summary?.debited.toLocaleString() ?? '—'} subtext="Includes purchases and negative adjustments" />
      <StatCard label="Net points balance" value={summary?.balance.toLocaleString() ?? '—'} subtext="All ledger entries, independent of filters" />
    </div>
    <div className="stepsy-card" style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 16, marginBottom: 20 }}>
      <label>Reason <select className="input-control" value={reason} onChange={e => setReason(e.target.value)}>{['ALL', 'STEP_EARN', 'OFFER_SPEND', 'ADJUST'].map(value => <option key={value} value={value}>{value.replaceAll('_', ' ')}</option>)}</select></label>
      <button className="btn btn-secondary" disabled={records.loading} onClick={() => { records.refresh(); refreshSummary(); }}>Refresh</button>
      <button className="btn btn-secondary" disabled={records.loading || !records.rows.length} onClick={() => downloadCsv('ledger-page.csv', records.rows, columns)}>Export this page</button>
    </div>
    {(records.error || summaryError) && <p role="alert" style={{ color: '#9F1239' }}>{records.error || summaryError}</p>}
    <div className="table-container"><table className="stepsy-table"><thead><tr>{columns.map(c => <th key={c.key}>{c.label}</th>)}</tr></thead><tbody>
      {records.loading ? <tr><td colSpan={5}>Loading ledger…</td></tr> : records.rows.length ? records.rows.map(row => <tr key={row.id}>{columns.map(c => <td key={c.key}>{c.key === 'created_at' ? new Date(row[c.key]).toLocaleString() : row[c.key] ?? '—'}</td>)}</tr>) : <tr><td colSpan={5}>No ledger entries match this filter.</td></tr>}
    </tbody></table></div>
    <RecordControls {...records} />
  </div>;
}
