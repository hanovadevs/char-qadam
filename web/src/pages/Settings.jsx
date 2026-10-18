import React from 'react';
import { useAdminQuery } from '../hooks/use-admin-query';

export default function Settings({ user }) {
  const { data: config, error } = useAdminQuery('/admin/config');
  return (
    <div className="container-main" style={{ maxWidth: '800px' }}>
      {/* Header */}
      <div style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '26px', fontWeight: '800', color: 'var(--brand-dark)' }}>
          System Configuration
        </h1>
        <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
          Stepsy platform parameters, rewards economy ratios, and backend integration status.
        </p>
      </div>

      {error && <p role="alert" style={{ color: 'var(--status-danger)' }}>Configuration could not be loaded: {error}</p>}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
        {/* Environment Profile */}
        <div className="stepsy-card">
          <h3 style={{ fontSize: '15px', fontWeight: '700', color: 'var(--brand-dark)', marginBottom: '16px' }}>
            Infrastructure & Gateway
          </h3>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: '12px', borderBottom: '1px solid var(--border-subtle)', fontSize: '13px' }}>
              <span style={{ color: 'var(--text-muted)' }}>Backend API Host</span>
              <span className="font-mono" style={{ fontWeight: '600', color: 'var(--text-primary)' }}>
                Configured API gateway
              </span>
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: '12px', borderBottom: '1px solid var(--border-subtle)', fontSize: '13px' }}>
              <span style={{ color: 'var(--text-muted)' }}>Web Deployment</span>
              <span style={{ fontWeight: '600', color: 'var(--text-primary)' }}>
                {window.location.host}
              </span>
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px' }}>
              <span style={{ color: 'var(--text-muted)' }}>Platform Environment</span>
              <span style={{ fontWeight: '700', color: 'var(--brand-teal)' }}>
                {config?.environment || 'Unavailable'}
              </span>
            </div>
          </div>
        </div>

        {/* Economy Parameters */}
        <div className="stepsy-card">
          <h3 style={{ fontSize: '15px', fontWeight: '700', color: 'var(--brand-dark)', marginBottom: '16px' }}>
            Rewards Economy Parameters
          </h3>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: '12px', borderBottom: '1px solid var(--border-subtle)', fontSize: '13px' }}>
              <span style={{ color: 'var(--text-muted)' }}>Step-to-Point Conversion Rate</span>
              <span style={{ fontWeight: '700', color: 'var(--text-primary)' }}>
                {config ? `${config.steps_per_point.toLocaleString()} Steps = 1 Point` : 'Unavailable'}
              </span>
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: '12px', borderBottom: '1px solid var(--border-subtle)', fontSize: '13px' }}>
              <span style={{ color: 'var(--text-muted)' }}>Daily Step Eligibility Cap</span>
              <span style={{ fontWeight: '700', color: 'var(--text-primary)' }}>
                {config ? `${config.daily_step_cap.toLocaleString()} Steps / Day` : 'Unavailable'}
              </span>
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px' }}>
              <span style={{ color: 'var(--text-muted)' }}>Default Voucher Validity Period</span>
              <span style={{ fontWeight: '700', color: 'var(--text-primary)' }}>
                {config ? `${config.voucher_validity_days} Days from Issuance` : 'Unavailable'}
              </span>
            </div>
          </div>
        </div>

        {/* Admin Account */}
        <div className="stepsy-card">
          <h3 style={{ fontSize: '15px', fontWeight: '700', color: 'var(--brand-dark)', marginBottom: '16px' }}>
            Active Administrator Session
          </h3>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: '12px', borderBottom: '1px solid var(--border-subtle)', fontSize: '13px' }}>
              <span style={{ color: 'var(--text-muted)' }}>Administrator Email</span>
              <span style={{ fontWeight: '600', color: 'var(--text-primary)' }}>
                {user?.email || 'admin@stepsy.app'}
              </span>
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px' }}>
              <span style={{ color: 'var(--text-muted)' }}>Authorization Method</span>
              <span className="font-mono" style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
                HMAC-SHA256 JWT Bearer Token
              </span>
            </div>
          </div>

          <div style={{ marginTop: '20px', paddingTop: '16px', borderTop: '1px solid var(--border-subtle)' }}>
            <button
              onClick={() => api.logout()}
              className="btn btn-danger btn-sm"
            >
              Sign Out from Console
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
