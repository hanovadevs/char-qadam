import React, { useState, useEffect } from 'react';
import { api } from '../services/api';
import Modal from '../components/Modal';
import Badge from '../components/Badge';
import { Search, Sliders, History, Edit, Trash2, BarChart2 } from 'lucide-react';

export default function Users() {
  const [users, setUsers] = useState([]);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Edit User Modal
  const [isEditOpen, setIsEditOpen] = useState(false);
  const [editingUser, setEditingUser] = useState(null);
  const [editForm, setEditForm] = useState({
    email: '',
    role: 'USER',
    status: 'ACTIVE',
  });
  const [isUpdatingUser, setIsUpdatingUser] = useState(false);

  // Adjust Points Modal
  const [adjustingUser, setAdjustingUser] = useState(null);
  const [delta, setDelta] = useState(100);
  const [reasonNote, setReasonNote] = useState('Customer support grant');
  const [adjusting, setAdjusting] = useState(false);

  // User Ledger Drawer
  const [ledgerUser, setLedgerUser] = useState(null);
  const [userLedger, setUserLedger] = useState([]);
  const [loadingLedger, setLoadingLedger] = useState(false);

  // User Activity & Progress Modal
  const [activityUser, setActivityUser] = useState(null);
  const [userActivity, setUserActivity] = useState(null);
  const [loadingActivity, setLoadingActivity] = useState(false);
  const [activityRange, setActivityRange] = useState('month');

  const fetchUsers = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await api.listUsers({
        search: search.trim() || undefined,
        status: statusFilter !== 'ALL' ? statusFilter : undefined,
      });
      setUsers(data || []);
    } catch (err) {
      setError(err.message || 'Error loading users.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUsers();
  }, [search, statusFilter]);

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

  const handleOpenActivity = async (user, range = 'month') => {
    setActivityUser(user);
    setActivityRange(range);
    setLoadingActivity(true);
    try {
      const data = await api.getUserActivity(user.id, range);
      setUserActivity(data);
    } catch (err) {
      alert(err.message || 'Failed to load user activity.');
    } finally {
      setLoadingActivity(false);
    }
  };

  const handleSwitchActivityRange = async (range) => {
    if (!activityUser) return;
    setActivityRange(range);
    setLoadingActivity(true);
    try {
      const data = await api.getUserActivity(activityUser.id, range);
      setUserActivity(data);
    } catch (err) {
      alert(err.message || 'Failed to load user activity.');
    } finally {
      setLoadingActivity(false);
    }
  };

  const openEditUser = (user) => {
    setEditingUser(user);
    setEditForm({
      email: user.email || '',
      role: user.role || 'USER',
      status: user.status || 'ACTIVE',
    });
    setIsEditOpen(true);
  };

  const handleUpdateUser = async (e) => {
    e.preventDefault();
    if (!editingUser || !editForm.email.trim()) return;

    setIsUpdatingUser(true);
    try {
      await api.updateUser(editingUser.id, {
        email: editForm.email.trim().toLowerCase(),
        role: editForm.role,
        status: editForm.status,
      });
      setIsEditOpen(false);
      fetchUsers();
    } catch (err) {
      alert(err.message || 'Failed to update user account.');
    } finally {
      setIsUpdatingUser(false);
    }
  };

  const handleDeleteUser = async (user) => {
    const confirmed = window.confirm(
      `Are you sure you want to permanently delete user "${user.email}"?\n\nThis will remove their account, device registrations, step activity records, points ledger, and claimed vouchers.`
    );
    if (!confirmed) return;

    try {
      await api.deleteUser(user.id);
      fetchUsers();
    } catch (err) {
      alert(err.message || 'Failed to delete user.');
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
            placeholder="Search users by email..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
          <span style={{ fontSize: '12px', color: 'var(--text-muted)', marginRight: '6px' }}>Status:</span>
          {['ALL', 'ACTIVE', 'SUSPENDED'].map((status) => (
            <button
              key={status}
              onClick={() => setStatusFilter(status)}
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
              <th>Role</th>
              <th>Status</th>
              <th>Available Points</th>
              <th>Joined Date</th>
              <th style={{ textAlign: 'right' }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={6} style={{ textAlign: 'center', padding: '40px 0', color: 'var(--text-muted)' }}>
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
                    <span
                      style={{
                        display: 'inline-flex',
                        alignItems: 'center',
                        padding: '2px 8px',
                        borderRadius: 'var(--radius-full)',
                        fontSize: '11px',
                        fontWeight: '700',
                        textTransform: 'uppercase',
                        letterSpacing: '0.04em',
                        background: u.role === 'MERCHANT' ? 'var(--tint-mint)' : 'var(--bg-surface-tertiary)',
                        color: u.role === 'MERCHANT' ? 'var(--brand-teal)' : 'var(--text-secondary)',
                        border: '1px solid var(--border-light)',
                      }}
                    >
                      {u.role || 'USER'}
                    </span>
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
                    <div style={{ display: 'inline-flex', gap: '6px' }}>
                      <button
                        onClick={() => {
                          setAdjustingUser(u);
                          setDelta(100);
                          setReasonNote('Customer support grant');
                        }}
                        className="btn btn-secondary btn-sm"
                        style={{ padding: '4px 8px', fontSize: '11px', height: '26px' }}
                        title="Adjust Points"
                      >
                        <Sliders size={12} />
                        <span>Adjust</span>
                      </button>

                      <button
                        onClick={() => handleOpenLedger(u)}
                        className="btn btn-ghost btn-sm"
                        style={{ padding: '4px 8px', fontSize: '11px', height: '26px' }}
                        title="View Points History"
                      >
                        <History size={12} />
                        <span>Ledger</span>
                      </button>

                      <button
                        onClick={() => handleOpenActivity(u, 'month')}
                        className="btn btn-ghost btn-sm"
                        style={{ padding: '4px 8px', fontSize: '11px', height: '26px' }}
                        title="View Step Activity & Trends"
                      >
                        <BarChart2 size={12} />
                        <span>Activity</span>
                      </button>

                      <button
                        onClick={() => openEditUser(u)}
                        className="btn btn-secondary btn-sm"
                        style={{ padding: '4px 8px', fontSize: '11px', height: '26px' }}
                        title="Edit User"
                      >
                        <Edit size={12} />
                        <span>Edit</span>
                      </button>

                      <button
                        onClick={() => handleDeleteUser(u)}
                        className="btn btn-danger btn-sm"
                        style={{ padding: '4px 8px', fontSize: '11px', height: '26px' }}
                        title="Delete User"
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
                <td colSpan={6} style={{ textAlign: 'center', padding: '40px 0', color: 'var(--text-muted)' }}>
                  No users found matching search.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

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
              placeholder="e.g. 500 or -200"
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
              placeholder="e.g. Promotion bonus, support compensation, correction"
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

      {/* Edit User Modal */}
      <Modal
        isOpen={isEditOpen}
        onClose={() => {
          setIsEditOpen(false);
          setEditingUser(null);
        }}
        title={`Edit User: ${editingUser?.email || ''}`}
        subtitle="Update user email, account role, or active status."
      >
        <form onSubmit={handleUpdateUser} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
          <div>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '4px' }}>
              Account Email *
            </label>
            <input
              type="email"
              required
              className="input-control"
              value={editForm.email}
              onChange={(e) => setEditForm({ ...editForm, email: e.target.value })}
            />
          </div>

          <div className="grid-cols-2" style={{ gap: '12px' }}>
            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '4px' }}>
                Account Role
              </label>
              <select
                className="input-control"
                value={editForm.role}
                onChange={(e) => setEditForm({ ...editForm, role: e.target.value })}
              >
                <option value="USER">Customer (USER)</option>
                <option value="MERCHANT">Partner Store (MERCHANT)</option>
              </select>
            </div>

            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '4px' }}>
                Account Status
              </label>
              <select
                className="input-control"
                value={editForm.status}
                onChange={(e) => setEditForm({ ...editForm, status: e.target.value })}
              >
                <option value="ACTIVE">ACTIVE</option>
                <option value="SUSPENDED">SUSPENDED</option>
              </select>
            </div>
          </div>

          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '16px' }}>
            <button
              type="button"
              onClick={() => {
                setIsEditOpen(false);
                setEditingUser(null);
              }}
              className="btn btn-ghost"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isUpdatingUser}
              className="btn btn-primary"
            >
              {isUpdatingUser ? 'Saving...' : 'Save Changes'}
            </button>
          </div>
        </form>
      </Modal>

      {/* User Activity & Progress Trends Modal */}
      <Modal
        isOpen={Boolean(activityUser)}
        onClose={() => {
          setActivityUser(null);
          setUserActivity(null);
        }}
        maxWidth="780px"
        title={`Activity & Step Trends: ${activityUser?.email || ''}`}
        subtitle="Review step sync history, daily averages, and periodic breakdown."
      >
        {/* Range Selector */}
        <div style={{ display: 'flex', gap: '8px', marginBottom: '16px', flexWrap: 'wrap' }}>
          {[
            { key: 'week', label: 'Past Week' },
            { key: 'month', label: 'Past Month' },
            { key: '3months', label: '3 Months' },
            { key: '6months', label: '6 Months' },
            { key: 'year', label: 'Past Year' },
            { key: 'all', label: 'All Time' },
          ].map((r) => (
            <button
              key={r.key}
              type="button"
              onClick={() => handleSwitchActivityRange(r.key)}
              className={activityRange === r.key ? 'btn btn-primary btn-sm' : 'btn btn-secondary btn-sm'}
              style={{ fontSize: '12px', padding: '4px 10px' }}
            >
              {r.label}
            </button>
          ))}
        </div>

        {loadingActivity ? (
          <div style={{ textAlign: 'center', padding: '40px 0', color: 'var(--text-muted)' }}>
            Loading step activity metrics...
          </div>
        ) : userActivity ? (
          <div>
            {/* Metric Cards */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '12px', marginBottom: '20px' }}>
              <div style={{ background: 'var(--bg-surface-secondary)', padding: '12px 14px', borderRadius: 'var(--radius-md)', border: '1px solid var(--border-light)' }}>
                <div style={{ fontSize: '11px', color: 'var(--text-muted)', fontWeight: '600', textTransform: 'uppercase' }}>Total Steps</div>
                <div style={{ fontSize: '20px', fontWeight: '800', color: 'var(--brand-teal)', marginTop: '4px' }}>
                  {(userActivity.total_steps || 0).toLocaleString()}
                </div>
              </div>

              <div style={{ background: 'var(--bg-surface-secondary)', padding: '12px 14px', borderRadius: 'var(--radius-md)', border: '1px solid var(--border-light)' }}>
                <div style={{ fontSize: '11px', color: 'var(--text-muted)', fontWeight: '600', textTransform: 'uppercase' }}>Daily Average</div>
                <div style={{ fontSize: '20px', fontWeight: '800', color: 'var(--brand-dark)', marginTop: '4px' }}>
                  {(userActivity.average_daily_steps || 0).toLocaleString()}
                </div>
              </div>

              <div style={{ background: 'var(--bg-surface-secondary)', padding: '12px 14px', borderRadius: 'var(--radius-md)', border: '1px solid var(--border-light)' }}>
                <div style={{ fontSize: '11px', color: 'var(--text-muted)', fontWeight: '600', textTransform: 'uppercase' }}>Today Steps</div>
                <div style={{ fontSize: '20px', fontWeight: '800', color: 'var(--brand-teal)', marginTop: '4px' }}>
                  {(userActivity.today_steps || 0).toLocaleString()}
                </div>
              </div>

              <div style={{ background: 'var(--bg-surface-secondary)', padding: '12px 14px', borderRadius: 'var(--radius-md)', border: '1px solid var(--border-light)' }}>
                <div style={{ fontSize: '11px', color: 'var(--text-muted)', fontWeight: '600', textTransform: 'uppercase' }}>Active Streak</div>
                <div style={{ fontSize: '20px', fontWeight: '800', color: 'var(--brand-dark)', marginTop: '4px' }}>
                  {userActivity.current_streak_days || 0} {userActivity.current_streak_days === 1 ? 'day' : 'days'}
                </div>
              </div>
            </div>

            {/* Visual Step Bar Chart */}
            {userActivity.periods && userActivity.periods.length > 0 ? (
              <div style={{ marginBottom: '20px', background: 'var(--bg-surface-secondary)', padding: '16px', borderRadius: 'var(--radius-md)', border: '1px solid var(--border-light)' }}>
                <div style={{ fontSize: '12px', fontWeight: '700', color: 'var(--text-secondary)', marginBottom: '14px' }}>
                  Step Activity Trend
                </div>
                {(() => {
                  const maxSteps = Math.max(...userActivity.periods.map((p) => p.steps), 1000);
                  const periodsSlice = userActivity.periods.slice(-30);
                  return (
                    <div style={{ display: 'flex', alignItems: 'flex-end', height: '140px', gap: '4px', paddingTop: '10px' }}>
                      {periodsSlice.map((p, idx) => {
                        const pct = Math.min(Math.max((p.steps / maxSteps) * 100, 3), 100);
                        const isToday = idx === periodsSlice.length - 1;
                        return (
                          <div
                            key={p.period_start}
                            style={{ flex: 1, height: '100%', display: 'flex', flexDirection: 'column', justifyContent: 'flex-end', alignItems: 'center' }}
                            title={`${new Date(p.period_start).toLocaleDateString()}: ${p.steps.toLocaleString()} steps`}
                          >
                            <div
                              style={{
                                width: '100%',
                                height: `${pct}%`,
                                minHeight: '4px',
                                background: isToday
                                  ? 'linear-gradient(180deg, #2FE0C4 0%, #0B4A47 100%)'
                                  : p.steps >= 1000
                                  ? '#0F8A78'
                                  : 'var(--border-dark)',
                                borderRadius: '3px 3px 0 0',
                                transition: 'height 0.2s ease',
                              }}
                            />
                          </div>
                        );
                      })}
                    </div>
                  );
                })()}
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '10px', color: 'var(--text-muted)', marginTop: '6px' }}>
                  <span>{new Date(userActivity.periods[Math.max(0, userActivity.periods.length - 30)].period_start).toLocaleDateString()}</span>
                  <span>Latest: {new Date(userActivity.periods[userActivity.periods.length - 1].period_start).toLocaleDateString()}</span>
                </div>
              </div>
            ) : null}

            {/* Detailed Table */}
            <div style={{ maxHeight: '240px', overflowY: 'auto' }}>
              <table className="stepsy-table">
                <thead>
                  <tr>
                    <th>Date / Period</th>
                    <th style={{ textAlign: 'right' }}>Steps Recorded</th>
                    <th style={{ textAlign: 'right' }}>Est. Distance</th>
                    <th style={{ textAlign: 'right' }}>Est. Calories</th>
                    <th>Source</th>
                  </tr>
                </thead>
                <tbody>
                  {userActivity.periods && userActivity.periods.length > 0 ? (
                    [...userActivity.periods].reverse().map((p) => (
                      <tr key={p.period_start}>
                        <td style={{ fontSize: '12px', fontWeight: '500' }}>
                          {new Date(p.period_start).toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' })}
                        </td>
                        <td className="font-mono" style={{ textAlign: 'right', fontWeight: '700', color: 'var(--brand-teal)' }}>
                          {(p.steps || 0).toLocaleString()}
                        </td>
                        <td style={{ textAlign: 'right', fontSize: '12px', color: 'var(--text-muted)' }}>
                          {((p.steps * 0.00078).toFixed(2))} km
                        </td>
                        <td style={{ textAlign: 'right', fontSize: '12px', color: 'var(--text-muted)' }}>
                          {((p.steps * 0.04).toFixed(0))} kcal
                        </td>
                        <td style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>
                          {p.source || 'APP'}
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan={5} style={{ textAlign: 'center', padding: '24px 0', color: 'var(--text-muted)' }}>
                        No step records for this range.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        ) : (
          <p style={{ textAlign: 'center', padding: '32px 0', color: 'var(--text-muted)', fontSize: '13px' }}>
            No activity data found.
          </p>
        )}
      </Modal>
    </div>
  );
}
