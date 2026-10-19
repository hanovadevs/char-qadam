import React, { useEffect, useRef, useState } from 'react';
import { api } from '../services/api';
import StoreCover from './StoreCover';

export default function StoreCoverEditor({ store, onSaved }) {
  const [file, setFile] = useState(null);
  const [preview, setPreview] = useState(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [saved, setSaved] = useState(false);
  const input = useRef(null);
  useEffect(() => {
    if (!file) { setPreview(null); return; }
    const url = URL.createObjectURL(file);
    setPreview(url);
    return () => URL.revokeObjectURL(url);
  }, [file]);
  const select = (event) => {
    const chosen = event.target.files?.[0];
    setSaved(false); setError(null); setFile(null);
    if (!chosen) return;
    if (chosen.size > 4 * 1024 * 1024 || (chosen.type && !['image/jpeg', 'image/png', 'image/webp'].includes(chosen.type))) {
      setError('Choose a JPEG, PNG or WebP smaller than 4 MB.'); event.target.value = ''; return;
    }
    setFile(chosen);
  };
  const save = async (remove = false) => {
    if (remove && !window.confirm('Remove this store cover?')) return;
    setBusy(true); setError(null); setSaved(false);
    try {
      const result = remove ? await api.removePartnerCover(store.id) : await api.uploadPartnerCover(store.id, file);
      onSaved(result.cover_image_url); setFile(null); setSaved(true);
      if (input.current) input.current.value = '';
    } catch (err) { setError(err.message); }
    finally { setBusy(false); }
  };
  return <section aria-label="Store cover">
    <label htmlFor={`cover-${store.id}`} style={{ fontSize: '12px', fontWeight: 600 }}>Store / brand cover</label>
    <div style={{ marginTop: '8px' }}><StoreCover src={preview || store.cover_image_url} name={store.name} preview /></div>
    <input ref={input} id={`cover-${store.id}`} type="file" accept="image/jpeg,image/png,image/webp" disabled={busy} onChange={select} />
    <p style={{ fontSize: '12px', color: 'var(--text-muted)', margin: '8px 0' }}>Use a wide photo. It will be cropped to 16:9 and optimized for the app. JPEG, PNG or WebP, up to 4 MB.</p>
    <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
      <button type="button" className="btn btn-primary btn-sm" disabled={!file || busy} onClick={() => save()}>{busy ? 'Saving cover…' : 'Save cover'}</button>
      {store.cover_image_url && <button type="button" className="btn btn-ghost btn-sm" disabled={busy} onClick={() => save(true)}>Remove cover</button>}
    </div>
    {saved && <p role="status" style={{ fontSize: '12px', color: 'var(--brand-teal)' }}>Cover saved. Reward cards will update after refresh.</p>}
    {error && <p role="alert" style={{ fontSize: '12px', color: 'var(--status-danger)' }}>{error}</p>}
  </section>;
}
