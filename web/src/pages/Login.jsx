import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../services/api';

export default function Login({ onLoginSuccess }) {
  const [email, setEmail] = useState('admin@stepsy.app');
  const [password, setPassword] = useState('admin123@');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const data = await api.login(email.trim(), password);
      if (onLoginSuccess) onLoginSuccess(data);
      navigate('/');
    } catch (err) {
      setError(err.message || 'Authentication failed. Please verify credentials.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div
      style={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        backgroundColor: 'var(--bg-canvas)',
        padding: '24px',
      }}
    >
      <div
        className="stepsy-card"
        style={{
          width: '100%',
          maxWidth: '400px',
          padding: '40px 32px',
          borderRadius: 'var(--radius-lg)',
        }}
      >
        {/* Brand Header */}
        <div style={{ textAlign: 'center', marginBottom: '32px' }}>
          <img
            src="/logo.png"
            alt="Stepsy"
            style={{ height: '48px', margin: '0 auto 16px auto', display: 'block' }}
          />
          <h2 style={{ fontSize: '22px', fontWeight: '800', color: 'var(--brand-dark)', letterSpacing: '-0.03em' }}>
            Stepsy Admin
          </h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
            Move More. Save More.
          </p>
        </div>

        {error && (
          <div
            style={{
              padding: '10px 14px',
              borderRadius: 'var(--radius-sm)',
              background: '#FFF1F2',
              border: '1px solid #FECDD3',
              color: '#9F1239',
              fontSize: '12px',
              marginBottom: '20px',
              fontWeight: '500',
            }}
          >
            {error}
          </div>
        )}

        {/* Form */}
        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          <div>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '6px' }}>
              Administrator Email
            </label>
            <input
              type="email"
              required
              className="input-control"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="admin@stepsy.app"
            />
          </div>

          <div>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '6px' }}>
              Password
            </label>
            <input
              type="password"
              required
              className="input-control"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="btn btn-primary"
            style={{ marginTop: '8px', width: '100%', padding: '11px' }}
          >
            {loading ? 'Authenticating...' : 'Sign In to Console'}
          </button>
        </form>

        <div style={{ marginTop: '24px', paddingTop: '20px', borderTop: '1px solid var(--border-subtle)', textAlign: 'center' }}>
          <span style={{ fontSize: '11px', color: 'var(--text-subtle)' }}>
            Stepsy Ecosystem Admin Portal &bull; v2.0
          </span>
        </div>
      </div>
    </div>
  );
}
