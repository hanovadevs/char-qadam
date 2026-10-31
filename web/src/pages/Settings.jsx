import React, { useEffect, useState } from 'react';
import { api } from '../services/api';
import { Link } from 'react-router-dom';

export default function Settings({ user }) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [result, setResult] = useState('');
  async function refresh() {
    setLoading(true);
    setError('');
    try { setData(await api.getSystemStatus()); }
    catch (err) { setError(err.message); }
    finally { setLoading(false); }
  }
  useEffect(() => { refresh(); }, []);
  async function expire() {
    if (!window.confirm(`Mark ${data.attention.overdue_vouchers} overdue vouchers as expired?`)) return;
    setLoading(true);
    setResult('');
    try {
      const response = await api.expireVouchers();
      setResult(`${response.swept_count} vouchers marked expired. The action was recorded in the audit log.`);
      await refresh();
    } catch (err) { setError(err.message); }
    finally { setLoading(false); }
  }
  const row = (label, value) => <div key={label} style={{ display: 'flex', justifyContent: 'space-between', gap: 20, padding: '12px 0', borderBottom: '1px solid var(--border-light)' }}><span>{label}</span><strong>{value}</strong></div>;
  return <div className="container-main" style={{ maxWidth: 900 }}>
    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 24 }}>
      <div><h1>System & Operations</h1><p>Live backend status, rewards rules, and voucher maintenance.</p></div>
      <button className="btn btn-secondary" disabled={loading} onClick={refresh}>{loading ? 'Checking…' : 'Refresh status'}</button>
    </div>
    {error && <p role="alert" style={{ color: '#9F1239' }}>{error}</p>}
    {result && <p role="status">{result}</p>}
    {data && <>
      <section className="stepsy-card" style={{ marginBottom: 20 }}><h2>Backend status</h2>
        {row('Environment', data.environment)}
        {row('Database', `${data.database.status} · ${data.database.latency_ms} ms`)}
        {row('Last checked', new Date(data.checked_at).toLocaleString())}
      </section>
      <section className="stepsy-card" style={{ marginBottom: 20 }}><h2>Rewards rules</h2>
        {row('Steps per point', data.rewards.steps_per_point.toLocaleString())}
        {row('Daily eligible step cap', data.rewards.daily_step_cap.toLocaleString())}
        {row('Voucher validity', `${data.rewards.voucher_validity_days} days`)}
      </section>
      <section className="stepsy-card" style={{ marginBottom: 20 }}><h2>Needs attention</h2>
        {row('Overdue vouchers awaiting expiry', data.attention.overdue_vouchers)}
        {row('Active offers with 10 or fewer items', data.attention.low_inventory_offers)}
        {row('Active offers past their end date', data.attention.ended_active_offers)}
        <button className="btn btn-primary" style={{ marginTop: 16 }} disabled={loading || !data.attention.overdue_vouchers} onClick={expire}>Expire overdue vouchers</button>
      </section>
    </>}
    {!data && loading && <p role="status">Checking backend…</p>}
    <section className="stepsy-card" style={{ marginBottom: 20 }}><h2>Customer support</h2><p>Manage tickets, reply to customers, and set AI usage limits.</p><Link className="btn btn-secondary" to="/support">Open support inbox</Link></section>
    <section className="stepsy-card"><h2>Administrator session</h2>{row('Email', user?.email || 'Unavailable')}
      <button className="btn btn-danger" style={{ marginTop: 16 }} onClick={() => api.logout()}>Sign out</button>
    </section>
  </div>;
}
