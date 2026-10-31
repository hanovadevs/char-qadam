import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { api } from '../services/api';
import { LogOut } from 'lucide-react';

export default function Navbar({ user }) {
  const navigate = useNavigate();

  const handleLogout = () => {
    api.logout();
  };

  const navItems = [
    { label: 'Overview', to: '/' },
    { label: 'Stores', to: '/stores' },
    { label: 'Deals', to: '/deals' },
    { label: 'Vouchers & POS', to: '/vouchers' },
    { label: 'Users', to: '/users' },
    { label: 'Ledger', to: '/ledger' },
    { label: 'Audit', to: '/audit' },
    { label: 'Support', to: '/support' },
    { label: 'Settings', to: '/settings' },
  ];

  return (
    <header className="apple-navbar">
      {/* Brand */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
        <img
          src="/logo-sage.png"
          alt="Stepsy Logo"
          style={{ height: '28px', width: 'auto', objectFit: 'contain' }}
        />
        <span style={{ fontSize: '18px', fontWeight: '800', color: 'var(--brand-dark)', letterSpacing: '-0.03em' }}>
          Stepsy
        </span>
        <span
          style={{
            fontSize: '11px',
            fontWeight: '700',
            textTransform: 'uppercase',
            letterSpacing: '0.06em',
            padding: '2px 8px',
            borderRadius: 'var(--radius-full)',
            background: 'var(--tint-mint-subtle)',
            color: 'var(--brand-teal)',
            border: '1px solid rgba(0, 210, 160, 0.3)',
          }}
        >
          Admin
        </span>
      </div>

      {/* Apple-style Segmented Pill Tabs */}
      <nav className="nav-pill-group">
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.to === '/'}
            className={({ isActive }) => `nav-pill-item ${isActive ? 'active' : ''}`}
          >
            {item.label}
          </NavLink>
        ))}
      </nav>

      {/* Admin Profile & Actions (Zero indicators, Zero glowing) */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
        <div style={{ textAlign: 'right' }}>
          <div style={{ fontSize: '12px', fontWeight: '600', color: 'var(--text-primary)' }}>
            {user?.email || 'Administrator'}
          </div>
          <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
            Superadmin
          </div>
        </div>

        <button
          onClick={handleLogout}
          className="btn btn-ghost btn-sm"
          title="Sign Out"
          style={{ color: 'var(--text-muted)', border: '1px solid var(--border-light)', borderRadius: 'var(--radius-sm)' }}
        >
          <LogOut size={14} />
          <span>Sign Out</span>
        </button>
      </div>
    </header>
  );
}
