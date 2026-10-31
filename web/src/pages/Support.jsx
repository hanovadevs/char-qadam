import React, { useEffect, useState } from 'react';
import { api } from '../services/api';
import { usePagedRecords } from '../hooks/usePagedRecords';
import RecordControls from '../components/RecordControls';
import Modal from '../components/Modal';
const load = filters => api.request(`/admin/support/tickets?${new URLSearchParams(filters)}`);
export default function Support() {
  const [status, setStatus] = useState('OPEN');
  const records = usePagedRecords(load, { status });
  const [ticket, setTicket] = useState(null);
  const [reply, setReply] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [ai, setAI] = useState(null);
  const [limits, setLimits] = useState(null);
  async function refreshAI() {
    try {
      const data = await api.request('/admin/support/ai');
      setAI(data);
      setLimits({ enabled: data.enabled, user_daily_limit: data.user_daily_limit, global_daily_limit: data.global_daily_limit, daily_token_budget: data.daily_token_budget });
    } catch (err) { setError(err.message); }
  }
  useEffect(() => { refreshAI(); }, []);
  async function open(id) {
    setBusy(true); setError('');
    try { setTicket(await api.request(`/admin/support/tickets/${id}`)); setReply(''); }
    catch (err) { setError(err.message); }
    finally { setBusy(false); }
  }
  async function send(event) {
    event.preventDefault(); setBusy(true); setError('');
    try {
      setTicket(await api.request(`/admin/support/tickets/${ticket.id}/messages`, { method: 'POST', body: JSON.stringify({ message: reply.trim() }) }));
      setReply(''); records.refresh();
    } catch (err) { setError(err.message); }
    finally { setBusy(false); }
  }
  async function changeStatus(value) {
    setBusy(true); setError('');
    try {
      const update = await api.request(`/admin/support/tickets/${ticket.id}`, { method: 'PATCH', body: JSON.stringify({ status: value }) });
      setTicket(previous => ({ ...previous, ...update })); records.refresh();
    } catch (err) { setError(err.message); }
    finally { setBusy(false); }
  }
  async function saveLimits(event) {
    event.preventDefault();
    if (limits.enabled && !window.confirm('Enable paid AI support with these daily request and token limits?')) return;
    setBusy(true); setError('');
    try { setAI(await api.request('/admin/support/ai', { method: 'PATCH', body: JSON.stringify(limits) })); }
    catch (err) { setError(err.message); }
    finally { setBusy(false); }
  }
  return <div className="container-main">
    <h1>Customer Support</h1><p>Reply to customer tickets and control AI support usage.</p>
    {error && <p role="alert" style={{ color: '#9F1239' }}>{error}</p>}
    {ai && limits && <section className="stepsy-card" style={{ margin: '20px 0' }}>
      <h2>AI cost controls</h2>
      <p>API key {ai.configured ? 'configured on server' : 'not configured'} · {ai.enabled ? 'Enabled' : 'Disabled'} · Model: {ai.model}</p>
      <p>Today (UTC): {ai.today.requests} requests · {ai.today.input_tokens.toLocaleString()} input tokens · {ai.today.output_tokens.toLocaleString()} output tokens · {ai.today.charged_tokens.toLocaleString()} tokens charged or reserved.</p>
      <form onSubmit={saveLimits} style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'end', gap: 16 }}>
        <label><input type="checkbox" checked={limits.enabled} disabled={!ai.configured || busy} onChange={e => setLimits({ ...limits, enabled: e.target.checked })} /> Enable AI help</label>
        {[['user_daily_limit', 'Questions per user per day', 1, 20], ['global_daily_limit', 'Total questions per day', 1, 1000], ['daily_token_budget', 'Daily token budget', 8192, 1000000]].map(([key, label, min, max]) => <label key={key}>{label}<input required type="number" className="input-control" min={min} max={max} value={limits[key]} onChange={e => setLimits({ ...limits, [key]: Number(e.target.value) })} /></label>)}
        <button className="btn btn-primary" disabled={busy}>Save AI controls</button>
        <button type="button" className="btn btn-secondary" disabled={busy} onClick={refreshAI}>Refresh usage</button>
      </form>
      <p style={{ marginTop: 12 }}>FAQ answers are free. AI questions have a 60-second cooldown and a 600-character limit. Replies are limited to 240 output tokens. Failed API attempts retain their token reservation.</p>
    </section>}
    <div className="stepsy-card" style={{ display: 'flex', gap: 16, alignItems: 'center', margin: '20px 0' }}>
      <label>Ticket status <select className="input-control" value={status} onChange={e => setStatus(e.target.value)}>{['ALL', 'OPEN', 'WAITING', 'RESOLVED'].map(value => <option key={value}>{value}</option>)}</select></label>
      <button className="btn btn-secondary" disabled={records.loading} onClick={records.refresh}>Refresh inbox</button>
    </div>
    {records.error && <p role="alert">{records.error}</p>}
    <div className="table-container"><table className="stepsy-table"><thead><tr><th>Customer</th><th>Subject</th><th>Category</th><th>Status</th><th>Updated</th><th>Action</th></tr></thead><tbody>
      {records.loading ? <tr><td colSpan={6}>Loading tickets…</td></tr> : records.rows.length ? records.rows.map(row => <tr key={row.id}><td>{row.user_email}</td><td>{row.subject}</td><td>{row.category}</td><td>{row.status}</td><td>{new Date(row.updated_at).toLocaleString()}</td><td><button className="btn btn-secondary btn-sm" disabled={busy} onClick={() => open(row.id)}>Open</button></td></tr>) : <tr><td colSpan={6}>No support tickets match this filter.</td></tr>}
    </tbody></table></div><RecordControls {...records} />
    <Modal isOpen={Boolean(ticket)} onClose={() => { if (!busy) setTicket(null); }} title={ticket?.subject || ''}>
      {ticket && <>
        <label>Status <select className="input-control" value={ticket.status} disabled={busy} onChange={e => changeStatus(e.target.value)}>{['OPEN', 'WAITING', 'RESOLVED'].map(value => <option key={value}>{value}</option>)}</select></label>
        <div style={{ maxHeight: 360, overflowY: 'auto', margin: '16px 0' }}>{ticket.messages.map(message => <article key={message.id} className="stepsy-card" style={{ marginBottom: 10 }}><strong>{message.author === 'ADMIN' ? 'Support team' : 'Customer'}</strong><time style={{ marginLeft: 12 }}>{new Date(message.created_at).toLocaleString()}</time><p style={{ whiteSpace: 'pre-wrap', overflowWrap: 'anywhere' }}>{message.message}</p></article>)}</div>
        <form onSubmit={send}><label>Reply to customer<textarea className="input-control" minLength={5} maxLength={2000} required rows={4} value={reply} onChange={e => setReply(e.target.value)} /></label><button className="btn btn-primary" disabled={busy || reply.trim().length < 5}>Send reply</button></form>
        {error && <p role="alert">{error}</p>}
      </>}
    </Modal>
  </div>;
}
