import React, { useState, useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { api } from './services/api';
import Navbar from './components/Navbar';
import Login from './pages/Login';
import Overview from './pages/Overview';
import Stores from './pages/Stores';
import Deals from './pages/Deals';
import Vouchers from './pages/Vouchers';
import Users from './pages/Users';
import Ledger from './pages/Ledger';
import Audit from './pages/Audit';
import Settings from './pages/Settings';
import Support from './pages/Support';

function ProtectedLayout({ user, children }) {
  if (!api.token) {
    return <Navigate to="/login" replace />;
  }

  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      <Navbar user={user} />
      <main style={{ flex: 1 }}>{children}</main>
    </div>
  );
}

export default function App() {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const initAuth = async () => {
      if (api.token) {
        try {
          const profile = await api.getMe();
          setUser(profile);
        } catch (err) {
          // The client clears an invalid session on 401. A transient network
          // failure must not discard a still-valid admin login.
          console.warn('Could not refresh admin profile:', err);
        }
      }
      setLoading(false);
    };

    initAuth();
  }, []);

  if (loading) {
    return (
      <div
        style={{
          minHeight: '100vh',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          backgroundColor: 'var(--bg-canvas)',
          color: 'var(--text-muted)',
          fontSize: '13px',
          fontWeight: '500',
        }}
      >
        Authenticating Stepsy Console...
      </div>
    );
  }

  return (
    <BrowserRouter>
      <Routes>
        <Route
          path="/login"
          element={
            api.token ? (
              <Navigate to="/" replace />
            ) : (
              <Login onLoginSuccess={(data) => setUser(data?.user || { email: 'admin@stepsy.app' })} />
            )
          }
        />

        <Route
          path="/"
          element={
            <ProtectedLayout user={user}>
              <Overview />
            </ProtectedLayout>
          }
        />

        <Route
          path="/stores"
          element={
            <ProtectedLayout user={user}>
              <Stores />
            </ProtectedLayout>
          }
        />

        <Route
          path="/deals"
          element={
            <ProtectedLayout user={user}>
              <Deals />
            </ProtectedLayout>
          }
        />

        <Route
          path="/vouchers"
          element={
            <ProtectedLayout user={user}>
              <Vouchers />
            </ProtectedLayout>
          }
        />

        <Route
          path="/users"
          element={
            <ProtectedLayout user={user}>
              <Users />
            </ProtectedLayout>
          }
        />

        <Route
          path="/ledger"
          element={
            <ProtectedLayout user={user}>
              <Ledger />
            </ProtectedLayout>
          }
        />

        <Route
          path="/audit"
          element={
            <ProtectedLayout user={user}>
              <Audit />
            </ProtectedLayout>
          }
        />

        <Route
          path="/settings"
          element={
            <ProtectedLayout user={user}>
              <Settings user={user} />
            </ProtectedLayout>
          }
        />

        <Route path="/support" element={<ProtectedLayout user={user}><Support /></ProtectedLayout>} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
