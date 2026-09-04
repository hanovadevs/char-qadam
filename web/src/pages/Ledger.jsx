import React, { useState, useEffect } from 'react';
import { api } from '../services/api';
import StatCard from '../components/StatCard';

export default function Ledger() {
  const [entries, setEntries] = useState([]);
  const [reasonFilter, setReasonFilter] = useState('ALL');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchLedger = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await api.getGlobalLedger({
        reason: reasonFilter !== 'ALL' ? reasonFilter : undefined,
      });
      setEntries(data || []);
    } catch (err) {
      setError(err.message || 'Failed to load global points ledger.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchLedger();
  }, [reasonFilter]);

  // Compute totals
  const totalMinted = entries.filter((e) => e.delta > 0).reduce((acc, e) => acc + e.delta, 0);
  const totalBurned = entries.filter((e) => e.delta < 0).reduce((acc, e) => acc + Math.abs(e.delta), 0);
  const netSupply = totalMinted - totalBurned;

  return (
    <div className="container-main">
      {/* Header */}
      <div style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '26px', fontWeight: '800', color: 'var(--brand-dark)' }}>
          Global Points Ledger
        </h1>
        <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
          Immutable double-entry points economy ledger tracking all step rewards and redemptions.
        </p>
      </div>

      {/* Stats row */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
          gap: '16px',
          marginBottom: '24px',
        }}
      >
        <StatCard
          label="Total Points Minted"
          value={`+${totalMinted.toLocaleString()}`}
          subtext="Earned through verified walking"
        />
        <StatCard
          label="Total Points Burned"
          value={`-${totalBurned.toLocaleString()}`}
          subtext="Exchanged for merchant vouchers"
        />
        <StatCard
          label="Net Circulating Supply"
          value={`${netSupply.toLocaleString()} PTS`}
          subtext="Currently held in user wallets"
        />
      </div>

      {/* Filter bar */}
      <div
        className="stepsy-card"
        style={{
          padding: '12px 18px',
          marginBottom: '20px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
        }}
      >
        <span style={{ fontSize: '13px', fontWeight: '600', color: 'var(--text-secondary)' }}>
          Filter by Ledger Reason
        </span>

        <div style={{ display: 'flex', gap: '6px' }}>
          {['ALL', 'DAILY_ACTIVITY', 'VOUCHER_PURCHASE', 'ADMIN_ADJUSTMENT'].map((r) => (
            <button
              key={r}
              onClick={() => setReasonFilter(r)}
              className="btn btn-sm"
              style={{
                background: reasonFilter === r ? 'var(--brand-dark)' : 'var(--bg-surface-tertiary)',
                color: reasonFilter === r ? 'var(--text-inverse)' : 'var(--text-secondary)',
                borderRadius: 'var(--radius-full)',
                padding: '4px 12px',
              }}
            >
              {r.replace('_', ' ')}
            </button>
          ))}
        </div>
      </div>

      {error && (
        <div style={{ padding: '12px 16px', background: '#FFF1F2', border: '1px solid #FECDD3', color: '#9F1239', borderRadius: 'var(--radius-sm)', marginBottom: '20px', fontSize: '13px' }}>
          {error}
        </div>
      )}

      {/* Ledger Table */}
      <div className="table-container">
        <table className="stepsy-table">
          <thead>
            <tr>
              <th>Timestamp</th>
              <th>User</th>
              <th>Reason Code</th>
              <th>Reference ID</th>
              <th style={{ textAlign: 'right' }}>Points Delta</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={5} style={{ textAlign: 'center', padding: '40px 0', color: 'var(--text-muted)' }}>
                  Loading ledger transactions...
                </td>
              </tr>
            ) : entries.length > 0 ? (
              entries.map((e) => (
                <tr key={e.id}>
                  <td style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                    {e.created_at ? new Date(e.created_at).toLocaleString() : 'N/A'}
                  </td>
                  <td style={{ fontWeight: '600', color: 'var(--text-primary)' }}>
                    {e.user_email || e.user_id || 'User'}
                  </td>
                  <td>
                    <span
                      style={{
                        fontSize: '11px',
                        fontWeight: '700',
                        textTransform: 'uppercase',
                        padding: '2px 8px',
                        borderRadius: 'var(--radius-full)',
                        background: 'var(--bg-canvas)',
                        border: '1px solid var(--border-light)',
                        color: 'var(--text-secondary)',
                      }}
                    >
                      {e.reason}
                    </span>
                  </td>
                  <td className="font-mono" style={{ fontSize: '11px', color: 'var(--text-subtle)' }}>
                    {e.ref_id || 'N/A'}
                  </td>
                  <td
                    className="font-mono"
                    style={{
                      textAlign: 'right',
                      fontWeight: '800',
                      fontSize: '14px',
                      color: e.delta > 0 ? 'var(--brand-teal)' : '#9F1239',
                    }}
                  >
                    {e.delta > 0 ? `+${e.delta}` : e.delta} PTS
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={5} style={{ textAlign: 'center', padding: '40px 0', color: 'var(--text-muted)' }}>
                  No ledger entries recorded yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
