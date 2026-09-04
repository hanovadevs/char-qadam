import React from 'react';
import { api } from '../services/api';

export default function Settings({ user }) {
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
                72.62.250.191 (FastAPI & PostgreSQL)
              </span>
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: '12px', borderBottom: '1px solid var(--border-subtle)', fontSize: '13px' }}>
              <span style={{ color: 'var(--text-muted)' }}>Web Deployment</span>
              <span style={{ fontWeight: '600', color: 'var(--text-primary)' }}>
                admin.stepsyapp.com (Vercel Global Edge)
              </span>
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px' }}>
              <span style={{ color: 'var(--text-muted)' }}>Platform Environment</span>
              <span style={{ fontWeight: '700', color: 'var(--brand-teal)' }}>
                PRODUCTION LIVE
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
                100 Steps = 1 Point
              </span>
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: '12px', borderBottom: '1px solid var(--border-subtle)', fontSize: '13px' }}>
              <span style={{ color: 'var(--text-muted)' }}>Daily Step Eligibility Cap</span>
              <span style={{ fontWeight: '700', color: 'var(--text-primary)' }}>
                30,000 Steps / Day
              </span>
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px' }}>
              <span style={{ color: 'var(--text-muted)' }}>Default Voucher Validity Period</span>
              <span style={{ fontWeight: '700', color: 'var(--text-primary)' }}>
                30 Days from Issuance
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
