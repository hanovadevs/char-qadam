import React, { useState, useEffect } from 'react';
import { api } from '../services/api';
import StatCard from '../components/StatCard';
import Badge from '../components/Badge';
import { Link } from 'react-router-dom';

export default function Overview() {
  const [metrics, setMetrics] = useState(null);
  const [charts, setCharts] = useState(null);
  const [recentRedemptions, setRecentRedemptions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const loadData = async () => {
    setLoading(true);
    setError(null);
    try {
      const [overviewData, chartData, redemptions] = await Promise.all([
        api.getAnalyticsOverview(),
        api.getAnalyticsCharts(),
        api.listRedemptions({ limit: 8 }),
      ]);
      setMetrics(overviewData);
      setCharts(chartData);
      setRecentRedemptions((redemptions || []).slice(0, 8));
    } catch (err) {
      setError(err.message || 'Failed to load ecosystem metrics.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const formatNumber = (num) => {
    if (num == null) return '0';
    return Number(num).toLocaleString();
  };

  const formatCurrency = (num) => {
    if (num == null) return '$0.00';
    return `$${Number(num).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
  };

  return (
    <div className="container-main">
      {/* Page Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '28px', flexWrap: 'wrap', gap: '16px' }}>
        <div>
          <h1 style={{ fontSize: '26px', fontWeight: '800', color: 'var(--brand-dark)' }}>
            Ecosystem Overview
          </h1>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
            Real-time synchronization across partner stores, active reward campaigns, and user step conversions.
          </p>
        </div>

        <div style={{ display: 'flex', gap: '10px' }}>
          <Link to="/stores" className="btn btn-secondary btn-sm">
            Manage Stores
          </Link>
          <Link to="/deals" className="btn btn-secondary btn-sm">
            Publish Deal
          </Link>
          <Link to="/vouchers" className="btn btn-primary btn-sm">
            POS Terminal
          </Link>
        </div>
      </div>

      {error && (
        <div
          style={{
            padding: '14px 18px',
            borderRadius: 'var(--radius-sm)',
            background: '#FFF1F2',
            border: '1px solid #FECDD3',
            color: '#9F1239',
            fontSize: '13px',
            marginBottom: '24px',
          }}
        >
          {error}
        </div>
      )}

      {/* 6 Key Metric Cards */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
          gap: '16px',
          marginBottom: '28px',
        }}
      >
        <StatCard
          label="Registered Users"
          value={loading ? '...' : formatNumber(metrics?.total_users)}
          subtext="Registered accounts"
        />
        <StatCard
          label="Eligible Steps"
          value={loading ? '...' : formatNumber(metrics?.total_steps)}
          subtext="Synced eligible step totals"
        />
        <StatCard
          label="Partner Stores"
          value={loading ? '...' : formatNumber(metrics?.active_partners)}
          subtext="Active merchant brands"
        />
        <StatCard
          label="Live Deals"
          value={loading ? '...' : formatNumber(metrics?.active_offers)}
          subtext="Published reward offers"
        />
        <StatCard
          label="Vouchers Redeemed"
          value={loading ? '...' : formatNumber(metrics?.vouchers_redeemed)}
          subtext="Completed POS redemptions"
        />
        <StatCard
          label="Fixed discounts redeemed"
          value={loading ? '...' : formatCurrency(metrics?.fixed_discount_value)}
          subtext="Face value; excludes percentage offers"
        />
      </div>

      {/* Analytics Chart & Activity Grid */}
      <div className="grid-cols-2" style={{ marginBottom: '28px' }}>
        {/* Step Trend Chart */}
        <div className="stepsy-card">
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
            <div>
              <h3 style={{ fontSize: '15px', fontWeight: '700', color: 'var(--text-primary)' }}>
                Daily Step Conversion Volume
              </h3>
              <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                Aggregated daily steps over the past 14 days
              </p>
            </div>
          </div>

          {/* Clean SVG Sparkline / Bar Chart */}
          <div style={{ height: '180px', display: 'flex', alignItems: 'flex-end', gap: '8px', padding: '10px 0', borderBottom: '1px solid var(--border-subtle)' }}>
            {charts?.daily_steps && charts.daily_steps.length > 0 ? (
              charts.daily_steps.map((d, i) => {
                const maxSteps = Math.max(...charts.daily_steps.map((s) => s.steps), 1);
                const heightPct = Math.max((d.steps / maxSteps) * 100, 6);
                return (
                  <div
                    key={d.date || i}
                    style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '6px' }}
                  >
                    <div
                      title={`${d.date}: ${formatNumber(d.steps)} steps`}
                      style={{
                        width: '100%',
                        height: `${heightPct}%`,
                        backgroundColor: 'var(--brand-mint)',
                        borderRadius: '4px 4px 0 0',
                        transition: 'height var(--transition-fast)',
                      }}
                    />
                    <span style={{ fontSize: '9px', color: 'var(--text-subtle)', transform: 'rotate(-45deg)', whiteSpace: 'nowrap' }}>
                      {d.date ? d.date.slice(5) : ''}
                    </span>
                  </div>
                );
              })
            ) : (
              <div style={{ width: '100%', textAlign: 'center', color: 'var(--text-subtle)', fontSize: '12px', padding: '40px 0' }}>
                No daily step activity recorded yet.
              </div>
            )}
          </div>
        </div>

        {/* Top Stores & Rankings */}
        <div className="stepsy-card">
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
            <div>
              <h3 style={{ fontSize: '15px', fontWeight: '700', color: 'var(--text-primary)' }}>
                Top Performing Merchant Stores
              </h3>
              <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                Ranked by volume of verified customer redemptions
              </p>
            </div>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            {charts?.top_partners && charts.top_partners.length > 0 ? (
              charts.top_partners.map((p, idx) => (
                <div
                  key={p.id}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    padding: '10px 14px',
                    background: 'var(--bg-canvas)',
                    borderRadius: 'var(--radius-sm)',
                    border: '1px solid var(--border-subtle)',
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <span
                      style={{
                        fontSize: '11px',
                        fontWeight: '700',
                        color: 'var(--brand-teal)',
                        background: 'var(--tint-mint-subtle)',
                        width: '24px',
                        height: '24px',
                        borderRadius: 'var(--radius-full)',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                      }}
                    >
                      #{idx + 1}
                    </span>
                    <div>
                      <div style={{ fontSize: '13px', fontWeight: '700', color: 'var(--text-primary)' }}>
                        {p.name}
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                        {p.count} redemptions
                      </div>
                    </div>
                  </div>

                  <span style={{ fontSize: '13px', fontWeight: '700', color: 'var(--brand-teal)', fontFamily: 'monospace' }}>
                    {formatCurrency(p.value)}
                  </span>
                </div>
              ))
            ) : (
              <div style={{ textAlign: 'center', padding: '32px 0', fontSize: '12px', color: 'var(--text-muted)' }}>
                Store rankings will appear once redemptions are processed.
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Recent Redemptions Table */}
      <div className="table-container">
        <div style={{ padding: '18px 20px', borderBottom: '1px solid var(--border-light)', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <h3 style={{ fontSize: '15px', fontWeight: '700', color: 'var(--text-primary)' }}>
              Recent POS Voucher Redemptions
            </h3>
            <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
              Most recent recorded voucher redemptions
            </p>
          </div>
          <Link to="/vouchers" style={{ fontSize: '12px', fontWeight: '600', color: 'var(--brand-teal)', textDecoration: 'none' }}>
            Open POS Terminal &rarr;
          </Link>
        </div>

        <table className="stepsy-table">
          <thead>
            <tr>
              <th>Voucher Code</th>
              <th>Deal Title</th>
              <th>Store Partner</th>
              <th>Discount Applied</th>
              <th>Redeemed Timestamp</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {recentRedemptions.length > 0 ? (
              recentRedemptions.map((r) => (
                <tr key={r.id}>
                  <td className="font-mono" style={{ fontWeight: '700', color: 'var(--brand-dark)' }}>
                    {r.short_code}
                  </td>
                  <td style={{ fontWeight: '600' }}>{r.offer_title || 'Deal Reward'}</td>
                  <td style={{ color: 'var(--text-secondary)' }}>{r.partner_name || 'Partner Store'}</td>
                  <td style={{ fontWeight: '700', color: 'var(--brand-teal)', fontFamily: 'monospace' }}>
                    {formatCurrency(r.discount_value)}
                  </td>
                  <td style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                    {r.redeemed_at ? new Date(r.redeemed_at).toLocaleString() : 'Unavailable'}
                  </td>
                  <td>
                    <Badge status="REDEEMED" label="REDEEMED" />
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={6} style={{ textAlign: 'center', padding: '40px 0', color: 'var(--text-muted)' }}>
                  No voucher redemptions recorded yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
