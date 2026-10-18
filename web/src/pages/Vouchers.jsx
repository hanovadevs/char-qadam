import React, { useState } from 'react';
import { useAdminQuery, useDebouncedValue } from '../hooks/use-admin-query';
import { queryPath } from '../services/read-cache';
import { api } from '../services/api';
import Badge from '../components/Badge';
import { Search, CheckCircle, AlertCircle, Trash2, XCircle } from 'lucide-react';

export default function Vouchers() {
  // POS Simulator State
  const [shortCode, setShortCode] = useState('');
  const [lookupResult, setLookupResult] = useState(null);
  const [lookingUp, setLookingUp] = useState(false);
  const [posError, setPosError] = useState(null);
  const [posSuccess, setPosSuccess] = useState(null);
  const [redeeming, setRedeeming] = useState(false);

  // Vouchers Table State
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const searchQuery = useDebouncedValue(search.trim());
  const { data: vouchers, loading, error, refresh: fetchVouchers } = useAdminQuery(
    queryPath('/admin/vouchers', { search: searchQuery, status: statusFilter }), []);

  const handleCancelVoucher = async (voucher) => {
    if (!window.confirm(`Are you sure you want to cancel voucher "${voucher.short_code}"?`)) return;
    try {
      await api.updateVoucher(voucher.id, { status: 'CANCELLED' });
      fetchVouchers();
    } catch (err) {
      alert(err.message || 'Failed to cancel voucher.');
    }
  };

  const handleDeleteVoucher = async (voucher) => {
    if (!window.confirm(`Are you sure you want to permanently delete voucher "${voucher.short_code}"?`)) return;
    try {
      await api.deleteVoucher(voucher.id);
      fetchVouchers();
    } catch (err) {
      alert(err.message || 'Failed to delete voucher.');
    }
  };

  const handleLookup = async (e) => {
    e.preventDefault();
    if (!shortCode.trim()) return;

    setLookingUp(true);
    setPosError(null);
    setPosSuccess(null);
    setLookupResult(null);

    try {
      const res = await api.lookupVoucher(shortCode.trim().toUpperCase());
      setLookupResult(res);
    } catch (err) {
      setPosError(err.message || 'Voucher code not found or invalid.');
    } finally {
      setLookingUp(false);
    }
  };

  const handleRedeem = async () => {
    if (!lookupResult) return;

    setRedeeming(true);
    setPosError(null);
    setPosSuccess(null);

    try {
      const res = await api.redeemVoucher({
        short_code: lookupResult.short_code,
        order_reference: `POS-ADMIN-${Date.now()}`,
      });
      setPosSuccess(`Voucher ${lookupResult.short_code} successfully redeemed!`);
      setLookupResult(null);
      setShortCode('');
      fetchVouchers();
    } catch (err) {
      setPosError(err.message || 'Failed to redeem voucher.');
    } finally {
      setRedeeming(false);
    }
  };

  return (
    <div className="container-main">
      {error && <p role="alert" style={{ color: 'var(--status-danger)' }}>{error}</p>}
      {/* Header */}
      <div style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '26px', fontWeight: '800', color: 'var(--brand-dark)' }}>
          Vouchers & Merchant POS Simulator
        </h1>
        <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
          Test machine-to-machine voucher validation and view issued customer voucher codes.
        </p>
      </div>

      {/* POS Simulator Card */}
      <div className="stepsy-card" style={{ marginBottom: '28px', background: 'var(--bg-surface)' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
          <div>
            <h3 style={{ fontSize: '15px', fontWeight: '700', color: 'var(--brand-dark)' }}>
              Point of Sale (POS) Verification Console
            </h3>
            <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
              Simulate cash counter voucher code lookup and real-time discount redemption
            </p>
          </div>
          <span
            style={{
              fontSize: '11px',
              fontWeight: '700',
              textTransform: 'uppercase',
              letterSpacing: '0.04em',
              background: 'var(--tint-mint-subtle)',
              color: 'var(--brand-teal)',
              padding: '3px 9px',
              borderRadius: 'var(--radius-full)',
              border: '1px solid rgba(0, 210, 160, 0.3)',
            }}
          >
            Live Terminal
          </span>
        </div>

        <form onSubmit={handleLookup} style={{ display: 'flex', gap: '10px', maxWidth: '500px' }}>
          <input
            type="text"
            required
            className="input-control font-mono"
            placeholder="Enter short code (e.g. ST-ABCD)"
            value={shortCode}
            onChange={(e) => setShortCode(e.target.value.toUpperCase())}
            style={{ textTransform: 'uppercase', fontWeight: '700', letterSpacing: '0.05em' }}
          />
          <button
            type="submit"
            disabled={lookingUp}
            className="btn btn-primary"
            style={{ whiteSpace: 'nowrap' }}
          >
            {lookingUp ? 'Verifying...' : 'Verify Code'}
          </button>
        </form>

        {posError && (
          <div
            style={{
              marginTop: '16px',
              padding: '12px 16px',
              background: '#FFF1F2',
              border: '1px solid #FECDD3',
              borderRadius: 'var(--radius-sm)',
              color: '#9F1239',
              fontSize: '13px',
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
            }}
          >
            <AlertCircle size={16} />
            <span>{posError}</span>
          </div>
        )}

        {posSuccess && (
          <div
            style={{
              marginTop: '16px',
              padding: '12px 16px',
              background: 'var(--tint-mint)',
              border: '1px solid rgba(0, 210, 160, 0.4)',
              borderRadius: 'var(--radius-sm)',
              color: 'var(--brand-teal)',
              fontSize: '13px',
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              fontWeight: '600',
            }}
          >
            <CheckCircle size={16} />
            <span>{posSuccess}</span>
          </div>
        )}

        {lookupResult && (
          <div
            style={{
              marginTop: '20px',
              padding: '18px 20px',
              background: 'var(--bg-canvas)',
              borderRadius: 'var(--radius-sm)',
              border: '1px solid var(--border-light)',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}>
              <div>
                <span className="font-mono" style={{ fontSize: '18px', fontWeight: '800', color: 'var(--brand-dark)' }}>
                  {lookupResult.short_code}
                </span>
                <h4 style={{ fontSize: '14px', fontWeight: '700', color: 'var(--text-primary)', marginTop: '4px' }}>
                  {lookupResult.offer_title || 'Deal Reward'}
                </h4>
                <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                  Partner: <strong>{lookupResult.partner_name || 'Store'}</strong> &bull; Customer: {lookupResult.user_email}
                </p>
              </div>

              <Badge status={lookupResult.status} />
            </div>

            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: '16px', paddingTop: '14px', borderTop: '1px solid var(--border-subtle)' }}>
              <div>
                <span style={{ fontSize: '11px', color: 'var(--text-muted)', textTransform: 'uppercase', display: 'block', fontWeight: '600' }}>
                  Discount Amount
                </span>
                <span style={{ fontSize: '20px', fontWeight: '800', color: 'var(--brand-teal)', fontFamily: 'monospace' }}>
                  ${(lookupResult.discount_value || 0).toFixed(2)}
                </span>
              </div>

              {lookupResult.status === 'ISSUED' ? (
                <button
                  type="button"
                  disabled={redeeming}
                  onClick={handleRedeem}
                  className="btn btn-primary"
                >
                  {redeeming ? 'Processing...' : 'Confirm Redemption at POS'}
                </button>
              ) : (
                <span style={{ fontSize: '12px', color: 'var(--text-muted)', fontWeight: '500' }}>
                  Voucher has already been {lookupResult.status.toLowerCase()}.
                </span>
              )}
            </div>
          </div>
        )}
      </div>

      {/* Vouchers Table */}
      <div className="table-container">
        <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--border-light)', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '12px' }}>
          <div>
            <h3 style={{ fontSize: '15px', fontWeight: '700', color: 'var(--text-primary)' }}>
              Issued Vouchers Directory
            </h3>
            <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
              Complete log of vouchers issued through point redemptions
            </p>
          </div>

          <div style={{ display: 'flex', gap: '10px' }}>
            <div style={{ position: 'relative', width: '220px' }}>
              <Search
                size={14}
                style={{ position: 'absolute', left: '10px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-subtle)' }}
              />
              <input
                type="text"
                className="input-control"
                style={{ paddingLeft: '32px', fontSize: '12px', padding: '6px 12px 6px 32px' }}
                placeholder="Search code or email..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>

            <select
              className="input-control"
              style={{ width: '130px', fontSize: '12px', padding: '6px 10px' }}
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
            >
              <option value="ALL">All Status</option>
              <option value="ISSUED">Issued</option>
              <option value="REDEEMED">Redeemed</option>
              <option value="EXPIRED">Expired</option>
            </select>
          </div>
        </div>

        <table className="stepsy-table">
          <thead>
            <tr>
              <th>Short Code</th>
              <th>Customer</th>
              <th>Deal Campaign</th>
              <th>Store</th>
              <th>Discount</th>
              <th>Issued At</th>
              <th>Status</th>
              <th style={{ textAlign: 'right' }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={8} style={{ textAlign: 'center', padding: '40px 0', color: 'var(--text-muted)' }}>
                  Loading vouchers...
                </td>
              </tr>
            ) : vouchers.length > 0 ? (
              vouchers.map((v) => (
                <tr key={v.id}>
                  <td className="font-mono" style={{ fontWeight: '700', color: 'var(--brand-dark)' }}>
                    {v.short_code}
                  </td>
                  <td style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
                    {v.user_email || 'User'}
                  </td>
                  <td style={{ fontWeight: '600' }}>
                    {v.offer_title || 'Deal'}
                  </td>
                  <td style={{ color: 'var(--text-secondary)' }}>
                    {v.partner_name || 'Store'}
                  </td>
                  <td style={{ fontWeight: '700', color: 'var(--brand-teal)', fontFamily: 'monospace' }}>
                    ${(v.discount_value || 0).toFixed(2)}
                  </td>
                  <td style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                    {v.issued_at ? new Date(v.issued_at).toLocaleDateString() : 'N/A'}
                  </td>
                  <td>
                    <Badge status={v.status} />
                  </td>
                  <td style={{ textAlign: 'right' }}>
                    <div style={{ display: 'inline-flex', gap: '6px' }}>
                      {v.status === 'ISSUED' && (
                        <button
                          type="button"
                          onClick={() => handleCancelVoucher(v)}
                          className="btn btn-secondary btn-sm"
                          style={{ padding: '3px 8px', fontSize: '11px', height: '26px' }}
                          title="Cancel Voucher"
                        >
                          <XCircle size={12} />
                          <span>Cancel</span>
                        </button>
                      )}
                      <button
                        type="button"
                        onClick={() => handleDeleteVoucher(v)}
                        className="btn btn-danger btn-sm"
                        style={{ padding: '3px 8px', fontSize: '11px', height: '26px' }}
                        title="Delete Voucher"
                      >
                        <Trash2 size={12} />
                        <span>Delete</span>
                      </button>
                    </div>
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={8} style={{ textAlign: 'center', padding: '40px 0', color: 'var(--text-muted)' }}>
                  No vouchers match the criteria.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
