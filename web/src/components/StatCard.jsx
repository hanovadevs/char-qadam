import React from 'react';

export default function StatCard({ label, value, subtext, delta }) {
  return (
    <div className="stepsy-card" style={{ padding: '20px 24px' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <span style={{ fontSize: '12px', fontWeight: '600', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
          {label}
        </span>
        {delta && (
          <span style={{ fontSize: '11px', fontWeight: '600', color: 'var(--brand-teal)' }}>
            {delta}
          </span>
        )}
      </div>

      <div style={{ fontSize: '28px', fontWeight: '800', color: 'var(--brand-dark)', marginTop: '8px', letterSpacing: '-0.03em' }}>
        {value}
      </div>

      {subtext && (
        <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px' }}>
          {subtext}
        </div>
      )}
    </div>
  );
}
