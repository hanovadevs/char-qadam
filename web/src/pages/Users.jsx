import React, { useState, useEffect, useRef } from 'react';
import { api } from '../services/api';
import Modal from '../components/Modal';
import Badge from '../components/Badge';
import { Search, Sliders, History } from 'lucide-react';

export default function Users() {
  const [users, setUsers] = useState([]);
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const requestVersion = useRef(0);
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Adjust Points Modal
  const [adjustingUser, setAdjustingUser] = useState(null);
  const [delta, setDelta] = useState(100);
  const [reasonNote, setReasonNote] = useState('Customer support grant');
  const [adjusting, setAdjusting] = useState(false);

  // User Ledger Drawer
  const [ledgerUser, setLedgerUser] = useState(null);
  const [userLedger, setUserLedger] = useState([]);
  const [loadingLedger, setLoadingLedger] = useState(false);

  const fetchUsers = async () => {
    const version = ++requestVersion.current;
    setLoading(true);
    setError(null);
    try {
      const data = await api.listUsers({
        limit: 51,
        offset: page * 50,
        search: search.trim() || undefined,
        status: statusFilter !== 'ALL' ? statusFilter : undefined,
      });
      if (version !== requestVersion.current) return;
      setHasMore((data || []).length > 50);
      setUsers((data || []).slice(0, 50));
    } catch (err) {
      if (version !== requestVersion.current) return;
      setError(err.message || 'Error loading users.');
    } finally {
      if (version === requestVersion.current) setLoading(false);
    }
  };

  useEffect(() => {
    const timer = setTimeout(fetchUsers, search ? 300 : 0);
    return () => {
      clearTimeout(timer);
      requestVersion.current += 1;
    };
  }, [search, statusFilter, page]);

  const handleAdjustPoints = async (e) => {
    e.preventDefault();
    if (!adjustingUser) return;

    setAdjusting(true);
    try {
      await api.adjustUserPoints(adjustingUser.id, {
        delta: Number(delta),
        reason_note: reasonNote.trim() || 'Manual adjustment',
      });
      setAdjustingUser(null);
      fetchUsers();
    } catch (err) {
      alert(err.message || 'Failed to adjust points.');
    } finally {
      setAdjusting(false);
    }
  };

  const handleOpenLedger = async (user) => {
    setLedgerUser(user);
    setLoadingLedger(true);
    try {
      const data = await api.getUserLedger(user.id);
      setUserLedger(data || []);
    } catch (err) {
      alert(err.message || 'Failed to load user ledger.');
      setLedgerUser(null);
    } finally {
      setLoadingLedger(false);
    }
  };

  const handleToggleStatus = async (user) => {
    const nextStatus = user.status === 'ACTIVE' ? 'SUSPENDED' : 'ACTIVE';
    if (!window.confirm(`Are you sure you want to change user status to ${nextStatus}?`)) return;

    try {
      await api.updateUserStatus(user.id, nextStatus);
      fetchUsers();
    } catch (err) {
      alert(err.message || 'Failed to update status.');
    }
  };

  return (
    <div className="container-main">
      {/* Header */}
      <div style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '26px', fontWeight: '800', color: 'var(--brand-dark)' }}>
          User Accounts & Rewards Balance
        </h1>
        <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
          Inspect user accounts, manage points ledger balances, and audit reward claims.
        </p>
      </div>

      {/* Filter bar */}
      <div
        className="stepsy-card"
        style={{
          padding: '12px 18px',
          marginBottom: '24px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          flexWrap: 'wrap',
          gap: '12px',
        }}
      >
        <div style={{ position: 'relative', width: '320px', maxWidth: '100%' }}>
          <Search
            size={16}
            style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-subtle)' }}
          />
          <input
            type="text"
            className="input-control"
            style={{ paddingLeft: '36px' }}
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(0); }}
          />
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
          <span style={{ fontSize: '12px', color: 'var(--text-muted)', marginRight: '6px' }}>Status:</span>
          {['ALL', 'ACTIVE', 'SUSPENDED'].map((status) => (
            <button
              key={status}
              onClick={() => { setStatusFilter(status); setPage(0); }}
              className="btn btn-sm"
              style={{
                background: statusFilter === status ? 'var(--brand-dark)' : 'var(--bg-surface-tertiary)',
                color: statusFilter === status ? 'var(--text-inverse)' : 'var(--text-secondary)',
                borderRadius: 'var(--radius-full)',
                padding: '4px 12px',
              }}
            >
              {status}
            </button>
          ))}
        </div>
      </div>

      {error && (
        <div style={{ padding: '12px 16px', background: '#FFF1F2', border: '1px solid #FECDD3', color: '#9F1239', borderRadius: 'var(--radius-sm)', marginBottom: '20px', fontSize: '13px' }}>
          {error}
        </div>
      )}

      {/* Users Table */}
      <div className="table-container">
        <table className="stepsy-table">
          <thead>
            <tr>
              <th>User Email</th>
              <th>Status</th>
              <th>Available Points</th>
              <th>Joined Date</th>
              <th style={{ textAlign: 'right' }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={5} style={{ textAlign: 'center', padding: '40px 0', color: 'var(--text-muted)' }}>
                  Loading users...
                </td>
              </tr>
            ) : users.length > 0 ? (
              users.map((u) => (
                <tr key={u.id}>
                  <td style={{ fontWeight: '600', color: 'var(--text-primary)' }}>
                    {u.email}
                  </td>
                  <td>
                    <Badge status={u.status} />
                  </td>
                  <td style={{ fontWeight: '800', color: 'var(--brand-teal)', fontFamily: 'monospace', fontSize: '14px' }}>
                    {(u.points_balance || 0).toLocaleString()} PTS
                  </td>
                  <td style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                    {u.created_at ? new Date(u.created_at).toLocaleDateString() : 'N/A'}
                  </td>
                  <td style={{ textAlign: 'right' }}>
                    <div style={{ display: 'inline-flex', gap: '8px' }}>
                      <button
                        onClick={() => {
                          setAdjustingUser(u);
                          setDelta(100);
                          setReasonNote('Customer support grant');
                        }}
                        className="btn btn-secondary btn-sm"
                        title="Adjust Points"
                      >
                        <Sliders size={13} />
                        <span>Adjust</span>
                      </button>

                      <button
                        onClick={() => handleOpenLedger(u)}
                        className="btn btn-ghost btn-sm"
                        title="View Points History"
                      >
                        <History size={13} />
                        <span>Ledger</span>
                      </button>

                      <button
                        onClick={() => handleToggleStatus(u)}
                        className="btn btn-ghost btn-sm"
                        style={{ color: u.status === 'ACTIVE' ? '#9F1239' : '#008B7A' }}
                      >
                        {u.status === 'ACTIVE' ? 'Suspend' : 'Activate'}
                      </button>
                    </div>
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={5} style={{ textAlign: 'center', padding: '40px 0', color: 'var(--text-muted)' }}>
                  No users found matching search.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      <nav aria-label="User pages" style={{ display: 'flex', justifyContent: 'flex-end', alignItems: 'center', gap: 12, marginTop: 16 }}>
        <button className="btn btn-secondary btn-sm" disabled={loading || page === 0} onClick={() => setPage(page - 1)}>Previous</button>
        <span>Page {page + 1}</span>
        <button className="btn btn-secondary btn-sm" disabled={loading || !hasMore} onClick={() => setPage(page + 1)}>Next</button>
      </nav>
      {/* Adjust Points Modal */}
      <Modal
        isOpen={Boolean(adjustingUser)}
        onClose={() => setAdjustingUser(null)}
        title={`Adjust Points for ${adjustingUser?.email || 'User'}`}
        subtitle="Credits or debits are written directly to the append-only points ledger."
      >
        <form onSubmit={handleAdjustPoints} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
          <div>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '4px' }}>
              Points Delta (Positive to Add, Negative to Deduct) *
            </label>
            <input
              type="number"
              required
              className="input-control font-mono"
              value={delta}
              onChange={(e) => setDelta(e.target.value)}
            />
          </div>

          <div>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '4px' }}>
              Mandatory Audit Reason Note *
            </label>
            <input
              type="text"
              required
              className="input-control"
              value={reasonNote}
              onChange={(e) => setReasonNote(e.target.value)}
            />
          </div>

          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '16px' }}>
            <button
              type="button"
              onClick={() => setAdjustingUser(null)}
              className="btn btn-ghost"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={adjusting}
              className="btn btn-primary"
            >
              {adjusting ? 'Submitting...' : 'Apply Points Adjustment'}
            </button>
          </div>
        </form>
      </Modal>

      {/* User Ledger History Modal */}
      <Modal
        isOpen={Boolean(ledgerUser)}
        onClose={() => {
          setLedgerUser(null);
          setUserLedger([]);
        }}
        maxWidth="640px"
        title={`Points Ledger: ${ledgerUser?.email || ''}`}
        subtitle="Chronological trail of points earned via steps and spent on deals."
      >
        {loadingLedger ? (
          <div style={{ textAlign: 'center', padding: '32px 0', color: 'var(--text-muted)' }}>
            Loading ledger transactions...
          </div>
        ) : userLedger.length > 0 ? (
          <div style={{ maxHeight: '380px', overflowY: 'auto' }}>
            <table className="stepsy-table">
              <thead>
                <tr>
                  <th>Timestamp</th>
                  <th>Reason</th>
                  <th style={{ textAlign: 'right' }}>Delta</th>
                </tr>
              </thead>
              <tbody>
                {userLedger.map((row) => (
                  <tr key={row.id}>
                    <td style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                      {row.created_at ? new Date(row.created_at).toLocaleString() : 'N/A'}
                    </td>
                    <td style={{ fontWeight: '500' }}>
                      {row.reason}
                    </td>
                    <td
                      className="font-mono"
                      style={{
                        textAlign: 'right',
                        fontWeight: '800',
                        color: row.delta > 0 ? 'var(--brand-teal)' : '#9F1239',
                      }}
                    >
                      {row.delta > 0 ? `+${row.delta}` : row.delta} PTS
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p style={{ textAlign: 'center', padding: '32px 0', color: 'var(--text-muted)', fontSize: '13px' }}>
            No points ledger entries recorded for this user yet.
          </p>
        )}
      </Modal>
    </div>
  );
}
