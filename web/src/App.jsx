import React, { lazy, Suspense, useState, useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { api } from './services/api';
import Navbar from './components/Navbar';
const Login = lazy(() => import('./pages/Login'));
const Overview = lazy(() => import('./pages/Overview'));
const Stores = lazy(() => import('./pages/Stores'));
const Deals = lazy(() => import('./pages/Deals'));
const Vouchers = lazy(() => import('./pages/Vouchers'));
const Users = lazy(() => import('./pages/Users'));
const Ledger = lazy(() => import('./pages/Ledger'));
const Audit = lazy(() => import('./pages/Audit'));
const Support = lazy(() => import('./pages/Support'));
const Settings = lazy(() => import('./pages/Settings'));

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
  const [authError, setAuthError] = useState('');

  useEffect(() => {
    const initAuth = async () => {
      if (api.token) {
        try {
          const profile = await api.getMe();
          setUser(profile);
        } catch (err) {
          if (api.token) setAuthError(err.message || 'Unable to reach the API.');
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

  if (authError) return <div className="container-main" role="alert"><h1>Unable to connect</h1><p>{authError}</p><button className="btn btn-primary" onClick={() => window.location.reload()}>Retry connection</button></div>;

  return (
    <BrowserRouter>
      <Suspense fallback={<div role="status" className="container-main">Loading page...</div>}>
      <Routes>
        <Route
          path="/login"
          element={
            api.token ? (
              <Navigate to="/" replace />
            ) : (
              <Login onLoginSuccess={(data) => setUser(data?.user || { email: 'Administrator' })} />
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
      </Suspense>
    </BrowserRouter>
  );
}
