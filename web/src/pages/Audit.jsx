import React, { useState, useEffect } from 'react';
import { api } from '../services/api';

export default function Audit() {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchAuditLogs = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await api.getAuditLogs();
      setLogs(data || []);
    } catch (err) {
      setError(err.message || 'Failed to load security audit logs.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAuditLogs();
  }, []);

  return (
    <div className="container-main">
      {/* Header */}
      <div style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '26px', fontWeight: '800', color: 'var(--brand-dark)' }}>
          Security Audit Logs
        </h1>
        <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
          Immutable audit trail capturing all administrative actions, partner modifications, and security events.
        </p>
      </div>

      {error && (
        <div style={{ padding: '12px 16px', background: '#FFF1F2', border: '1px solid #FECDD3', color: '#9F1239', borderRadius: 'var(--radius-sm)', marginBottom: '20px', fontSize: '13px' }}>
          {error}
        </div>
      )}

      {/* Audit Table */}
      <div className="table-container">
        <table className="stepsy-table">
          <thead>
            <tr>
              <th>Timestamp</th>
              <th>Actor</th>
              <th>Security Action</th>
              <th>Object Target</th>
              <th>Object ID</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={5} style={{ textAlign: 'center', padding: '40px 0', color: 'var(--text-muted)' }}>
                  Loading audit trail...
                </td>
              </tr>
            ) : logs.length > 0 ? (
              logs.map((log) => (
                <tr key={log.id}>
                  <td style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                    {log.created_at ? new Date(log.created_at).toLocaleString() : 'N/A'}
                  </td>
                  <td>
                    <span style={{ fontWeight: '700', color: 'var(--text-primary)' }}>
                      {log.actor}
                    </span>
                  </td>
                  <td>
                    <span
                      style={{
                        fontSize: '11px',
                        fontWeight: '700',
                        fontFamily: 'monospace',
                        color: 'var(--brand-teal)',
                        background: 'var(--tint-mint-subtle)',
                        padding: '3px 8px',
                        borderRadius: 'var(--radius-xs)',
                        border: '1px solid rgba(0, 210, 160, 0.25)',
                      }}
                    >
                      {log.action}
                    </span>
                  </td>
                  <td style={{ color: 'var(--text-secondary)' }}>
                    {log.object_type}
                  </td>
                  <td className="font-mono" style={{ fontSize: '11px', color: 'var(--text-subtle)' }}>
                    {log.object_id || 'N/A'}
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={5} style={{ textAlign: 'center', padding: '40px 0', color: 'var(--text-muted)' }}>
                  No security audit events recorded.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
