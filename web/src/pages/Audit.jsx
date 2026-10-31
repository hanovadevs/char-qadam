import React, { useState } from 'react';
import { api } from '../services/api';
import { usePagedRecords } from '../hooks/usePagedRecords';
import RecordControls from '../components/RecordControls';
import { downloadCsv } from '../utils/csv';
const load = filters => api.getAuditLogs(filters);
const columns = [{ key: 'created_at', label: 'Timestamp' }, { key: 'actor', label: 'Actor' }, { key: 'action', label: 'Action' }, { key: 'object_type', label: 'Object type' }, { key: 'object_id', label: 'Object ID' }];
export default function Audit() {
  const [action, setAction] = useState('');
  const [actor, setActor] = useState('');
  const records = usePagedRecords(load, { action, actor });
  return <div className="container-main">
    <h1>Security Audit Logs</h1><p>Recorded administrative and security events.</p>
    <div className="stepsy-card" style={{ display: 'flex', flexWrap: 'wrap', gap: 16, margin: '20px 0' }}>
      <label>Action contains<input className="input-control" value={action} onChange={e => setAction(e.target.value)} maxLength={128} /></label>
      <label>Actor ID<input className="input-control" value={actor} onChange={e => setActor(e.target.value)} maxLength={36} /></label>
      <button className="btn btn-secondary" disabled={records.loading} onClick={records.refresh}>Refresh</button>
      <button className="btn btn-secondary" disabled={records.loading || !records.rows.length} onClick={() => downloadCsv('audit-page.csv', records.rows, columns)}>Export this page</button>
    </div>
    {records.error && <p role="alert" style={{ color: '#9F1239' }}>{records.error}</p>}
    <div className="table-container"><table className="stepsy-table"><thead><tr>{columns.map(c => <th key={c.key}>{c.label}</th>)}</tr></thead><tbody>
      {records.loading ? <tr><td colSpan={5}>Loading audit events…</td></tr> : records.rows.length ? records.rows.map(row => <tr key={row.id}>{columns.map(c => <td key={c.key}>{c.key === 'created_at' ? new Date(row[c.key]).toLocaleString() : row[c.key] || '—'}</td>)}</tr>) : <tr><td colSpan={5}>No audit events match these filters.</td></tr>}
    </tbody></table></div>
    <RecordControls {...records} />
  </div>;
}
