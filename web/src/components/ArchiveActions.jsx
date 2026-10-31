import React, { useState } from 'react';
import { Archive, RotateCcw, Trash2 } from 'lucide-react';
import { api } from '../services/api';

export default function ArchiveActions({ kind, record, onChanged }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const archived = Boolean(record.archived_at);
  const label = record.name || record.title;
  const mutate = async (action, event) => {
    event.stopPropagation();
    const message = action === 'delete'
      ? `Permanently delete "${label}"? This cannot be undone. The server will reject deletion if it has customer history.`
      : action === 'archive'
        ? `Archive "${label}"? It will be hidden from new claims. Existing vouchers and history will be kept.`
        : `Restore "${label}"? Its previous active/inactive status and schedule will still apply.`;
    if (!window.confirm(message)) return;
    setBusy(true); setError(null);
    try {
      await api.request(`/admin/${kind}/${record.id}${action === 'delete' ? '' : `/${action}`}`,
        { method: action === 'delete' ? 'DELETE' : 'POST' });
      onChanged?.(action);
    } catch (err) { setError(err.message); }
    finally { setBusy(false); }
  };
  return <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap', alignItems: 'center' }}>
    <button type="button" className="btn btn-secondary btn-sm" disabled={busy}
      onClick={(event) => mutate(archived ? 'restore' : 'archive', event)}>
      {archived ? <RotateCcw size={12} /> : <Archive size={12} />}
      {archived ? 'Restore' : 'Archive'}
    </button>
    {archived && record.can_delete === true && <button type="button" className="btn btn-danger btn-sm"
      disabled={busy} onClick={(event) => mutate('delete', event)}>
      <Trash2 size={12} />Delete permanently
    </button>}
    {archived && record.can_delete === false && <span style={{ fontSize: '11px', color: 'var(--text-muted)' }}>History preserved</span>}
    {error && <span role="alert" style={{ fontSize: '12px', color: 'var(--status-danger)' }}>{error}</span>}
  </div>;
}
