import React, { useEffect, useState } from 'react';

export default function StoreCover({ src, name, preview = false }) {
  const [failed, setFailed] = useState(false);
  useEffect(() => setFailed(false), [src]);
  if (!src && !preview) return null;
  return <div style={{ aspectRatio: '16 / 9', overflow: 'hidden', borderRadius: 'var(--radius-sm)',
    background: 'var(--tint-mint-subtle)', marginBottom: '16px', display: 'grid', placeItems: 'center' }}>
    {src && !failed ? <img src={src} alt={`${name || 'Store'} cover`} loading="lazy" decoding="async"
      onError={() => setFailed(true)} style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />
      : <span style={{ color: 'var(--brand-teal)', fontSize: '14px' }}>{name || 'Store cover'}</span>}
  </div>;
}
