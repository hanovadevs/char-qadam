import React, { useState, useEffect } from 'react';
import { api } from '../services/api';
import Modal from '../components/Modal';
import Badge from '../components/Badge';
import { Search, Plus, Copy, Check } from 'lucide-react';

export default function Stores() {
  const [stores, setStores] = useState([]);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Modals state
  const [isRegisterOpen, setIsRegisterOpen] = useState(false);
  const [selectedStore, setSelectedStore] = useState(null);
  const [storeDetails, setStoreDetails] = useState(null);
  const [loadingDetails, setLoadingDetails] = useState(false);

  // New Store Form
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    password: '',
    status: 'ACTIVE',
    generate_api_key: true,
  });
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [createdPartner, setCreatedPartner] = useState(null);
  const [copiedKey, setCopiedKey] = useState(null);

  // New Deal Form in Store
  const [isAddDealOpen, setIsAddDealOpen] = useState(false);
  const [dealForm, setDealForm] = useState({
    title: '',
    description: '',
    discount_type: 'PERCENT',
    discount_value: 15,
    points_cost: 200,
    min_basket: 0,
    inventory: 100,
    status: 'ACTIVE',
  });
  const [isSubmittingDeal, setIsSubmittingDeal] = useState(false);

  const fetchStores = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await api.listPartners({
        search: search.trim() || undefined,
        status: statusFilter !== 'ALL' ? statusFilter : undefined,
      });
      setStores(data || []);
    } catch (err) {
      setError(err.message || 'Error loading partner stores.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStores();
  }, [search, statusFilter]);

  const handleCreateStore = async (e) => {
    e.preventDefault();
    if (!formData.name.trim()) return;

    setIsSubmitting(true);
    try {
      const data = await api.createPartner({
        name: formData.name.trim(),
        email: formData.email.trim() || undefined,
        password: formData.password || undefined,
        status: formData.status,
        generate_api_key: formData.generate_api_key,
      });
      setCreatedPartner(data);
      fetchStores();
    } catch (err) {
      alert(err.message || 'Failed to create partner store.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const openStoreDetails = async (storeId) => {
    setSelectedStore(storeId);
    setLoadingDetails(true);

    const baseStore = stores.find((s) => s.id === storeId) || { id: storeId, name: 'Store' };

    try {
      const data = await api.getPartner(storeId);
      setStoreDetails(data);
    } catch (err) {
      // Graceful fallback to listOffers + listRedemptions
      try {
        const [offersData, redemptionsData] = await Promise.all([
          api.listOffers({ partner_id: storeId }),
          api.listRedemptions(),
        ]);
        const storeRedemptions = (redemptionsData || []).filter(
          (r) => r.partner_name === baseStore.name || r.partner_id === storeId
        );
        setStoreDetails({
          ...baseStore,
          offers: offersData || [],
          recent_redemptions: storeRedemptions || [],
        });
      } catch (fallbackErr) {
        setStoreDetails({
          ...baseStore,
          offers: [],
          recent_redemptions: [],
        });
      }
    } finally {
      setLoadingDetails(false);
    }
  };

  const handleRegenerateKey = async (storeId) => {
    if (!window.confirm('Are you sure? Any existing POS terminal using the previous key will stop working.')) return;
    try {
      const res = await api.regeneratePartnerKey(storeId);
      if (storeDetails) {
        setStoreDetails({ ...storeDetails, has_api_key: true, raw_api_key: res.raw_api_key });
      }
      fetchStores();
    } catch (err) {
      alert(err.message || 'Failed to regenerate key.');
    }
  };

  const handleCreateDealForStore = async (e) => {
    e.preventDefault();
    if (!storeDetails || !dealForm.title) return;

    setIsSubmittingDeal(true);
    try {
      await api.createOffer({
        partner_id: storeDetails.id,
        title: dealForm.title,
        description: dealForm.description || undefined,
        discount_type: dealForm.discount_type,
        discount_value: Number(dealForm.discount_value),
        points_cost: Number(dealForm.points_cost),
        min_basket: dealForm.min_basket ? Number(dealForm.min_basket) : undefined,
        inventory: dealForm.inventory ? Number(dealForm.inventory) : undefined,
        status: dealForm.status,
      });
      setIsAddDealOpen(false);
      openStoreDetails(storeDetails.id);
      fetchStores();
    } catch (err) {
      alert(err.message || 'Failed to create deal.');
    } finally {
      setIsSubmittingDeal(false);
    }
  };

  const copyToClipboard = (text) => {
    navigator.clipboard.writeText(text);
    setCopiedKey(text);
    setTimeout(() => setCopiedKey(null), 2500);
  };

  return (
    <div className="container-main">
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '24px', flexWrap: 'wrap', gap: '16px' }}>
        <div>
          <h1 style={{ fontSize: '26px', fontWeight: '800', color: 'var(--brand-dark)' }}>
            Partner Stores
          </h1>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
            Register new partner stores, provision POS API keys, and manage brand campaigns.
          </p>
        </div>

        <button
          onClick={() => {
            setCreatedPartner(null);
            setFormData({ name: '', email: '', password: '', status: 'ACTIVE', generate_api_key: true });
            setIsRegisterOpen(true);
          }}
          className="btn btn-primary"
        >
          <Plus size={16} />
          <span>Register New Store</span>
        </button>
      </div>

      {/* Filters Bar */}
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
            placeholder="Search stores by brand or email..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
          <span style={{ fontSize: '12px', color: 'var(--text-muted)', marginRight: '6px' }}>Status:</span>
          {['ALL', 'ACTIVE', 'INACTIVE'].map((status) => (
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

      {/* Stores Grid */}
      {loading ? (
        <div style={{ textAlign: 'center', padding: '60px 0', color: 'var(--text-muted)', fontSize: '13px' }}>
          Loading partner stores...
        </div>
      ) : stores.length === 0 ? (
        <div className="stepsy-card" style={{ textAlign: 'center', padding: '48px 24px' }}>
          <h3 style={{ fontSize: '16px', fontWeight: '700', color: 'var(--text-primary)' }}>
            No Partner Stores Found
          </h3>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
            {search || statusFilter !== 'ALL'
              ? 'Try changing your search keywords or status filter.'
              : 'Click "Register New Store" to add your first partner brand.'}
          </p>
        </div>
      ) : (
        <div className="grid-cols-3">
          {stores.map((s) => (
            <div
              key={s.id}
              className="stepsy-card"
              onClick={() => openStoreDetails(s.id)}
              style={{
                cursor: 'pointer',
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'space-between',
              }}
            >
              <div>
                {/* Header: Initial Avatar & Name */}
                <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: '16px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    <div
                      style={{
                        width: '40px',
                        height: '40px',
                        borderRadius: 'var(--radius-sm)',
                        background: 'var(--tint-mint-subtle)',
                        color: 'var(--brand-teal)',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        fontSize: '16px',
                        fontWeight: '800',
                      }}
                    >
                      {(s.name || 'S').charAt(0).toUpperCase()}
                    </div>
                    <div>
                      <h3 style={{ fontSize: '15px', fontWeight: '700', color: 'var(--text-primary)' }}>
                        {s.name}
                      </h3>
                      <p style={{ fontSize: '12px', color: 'var(--text-muted)', maxWidth: '160px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {s.email || 'No login email'}
                      </p>
                    </div>
                  </div>

                  <Badge status={s.status} />
                </div>

                {/* Metrics 3-Col Bar */}
                <div
                  style={{
                    display: 'grid',
                    gridTemplateColumns: 'repeat(3, 1fr)',
                    gap: '8px',
                    padding: '10px 12px',
                    background: 'var(--bg-canvas)',
                    borderRadius: 'var(--radius-sm)',
                    border: '1px solid var(--border-subtle)',
                    textAlign: 'center',
                  }}
                >
                  <div>
                    <span style={{ fontSize: '10px', color: 'var(--text-muted)', textTransform: 'uppercase', display: 'block', fontWeight: '600' }}>
                      Deals
                    </span>
                    <span style={{ fontSize: '14px', fontWeight: '800', color: 'var(--text-primary)' }}>
                      {s.offer_count || 0}
                    </span>
                  </div>
                  <div>
                    <span style={{ fontSize: '10px', color: 'var(--text-muted)', textTransform: 'uppercase', display: 'block', fontWeight: '600' }}>
                      Redeemed
                    </span>
                    <span style={{ fontSize: '14px', fontWeight: '800', color: 'var(--brand-teal)' }}>
                      {s.redemption_count || 0}
                    </span>
                  </div>
                  <div>
                    <span style={{ fontSize: '10px', color: 'var(--text-muted)', textTransform: 'uppercase', display: 'block', fontWeight: '600' }}>
                      Discounts
                    </span>
                    <span style={{ fontSize: '14px', fontWeight: '800', color: 'var(--brand-dark)', fontFamily: 'monospace' }}>
                      ${(s.total_discount_value || 0).toFixed(0)}
                    </span>
                  </div>
                </div>
              </div>

              {/* Card Footer */}
              <div style={{ marginTop: '18px', paddingTop: '12px', borderTop: '1px solid var(--border-subtle)', display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: '12px' }}>
                <span style={{ color: 'var(--text-muted)', fontSize: '11px', fontWeight: '500' }}>
                  {s.has_api_key ? 'POS Key Active' : 'No API Key'}
                </span>
                <span style={{ color: 'var(--brand-teal)', fontWeight: '600' }}>
                  Manage Store &rarr;
                </span>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Register Store Modal */}
      <Modal
        isOpen={isRegisterOpen}
        onClose={() => setIsRegisterOpen(false)}
        title={createdPartner ? 'Store Registered Successfully' : 'Register New Partner Store'}
        subtitle={
          createdPartner
            ? 'The store is now provisioned on Stepsy. Copy the generated POS API key below.'
            : 'Enter merchant credentials and machine-to-machine integration settings.'
        }
      >
        {createdPartner ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div style={{ padding: '16px', background: 'var(--tint-mint)', border: '1px solid rgba(0, 210, 160, 0.4)', borderRadius: 'var(--radius-sm)' }}>
              <h4 style={{ fontSize: '14px', fontWeight: '700', color: 'var(--brand-teal)' }}>
                {createdPartner.name}
              </h4>
              <p style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px' }}>
                Login Email: <strong>{createdPartner.email || 'None configured'}</strong>
              </p>

              {createdPartner.raw_api_key && (
                <div style={{ marginTop: '12px' }}>
                  <label style={{ display: 'block', fontSize: '11px', fontWeight: '700', color: 'var(--brand-dark)', marginBottom: '4px', textTransform: 'uppercase' }}>
                    Machine-to-Machine POS API Key (Shown Once)
                  </label>
                  <div style={{ display: 'flex', gap: '8px' }}>
                    <input
                      type="text"
                      readOnly
                      className="input-control font-mono"
                      value={createdPartner.raw_api_key}
                      style={{ fontSize: '11px' }}
                    />
                    <button
                      type="button"
                      onClick={() => copyToClipboard(createdPartner.raw_api_key)}
                      className="btn btn-secondary btn-sm"
                    >
                      {copiedKey === createdPartner.raw_api_key ? <Check size={14} /> : <Copy size={14} />}
                      <span>{copiedKey === createdPartner.raw_api_key ? 'Copied' : 'Copy'}</span>
                    </button>
                  </div>
                </div>
              )}
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '8px' }}>
              <button
                type="button"
                onClick={() => setIsRegisterOpen(false)}
                className="btn btn-primary"
              >
                Done
              </button>
            </div>
          </div>
        ) : (
          <form onSubmit={handleCreateStore} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '4px' }}>
                Store / Brand Name *
              </label>
              <input
                type="text"
                required
                className="input-control"
                placeholder="e.g. Nike Pakistan, Outfitters, Gloria Jean's"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              />
            </div>

            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '4px' }}>
                Merchant Contact Email (Optional)
              </label>
              <input
                type="email"
                className="input-control"
                placeholder="store@brand.com"
                value={formData.email}
                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
              />
            </div>

            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '4px' }}>
                Initial Password (Optional)
              </label>
              <input
                type="password"
                className="input-control"
                placeholder="Minimum 6 characters"
                value={formData.password}
                onChange={(e) => setFormData({ ...formData, password: e.target.value })}
              />
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', paddingTop: '4px' }}>
              <input
                type="checkbox"
                id="gen_key"
                checked={formData.generate_api_key}
                onChange={(e) => setFormData({ ...formData, generate_api_key: e.target.checked })}
              />
              <label htmlFor="gen_key" style={{ fontSize: '12px', color: 'var(--text-secondary)', cursor: 'pointer' }}>
                Automatically generate a live POS integration key (pk_live_...)
              </label>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '16px' }}>
              <button
                type="button"
                onClick={() => setIsRegisterOpen(false)}
                className="btn btn-ghost"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isSubmitting}
                className="btn btn-primary"
              >
                {isSubmitting ? 'Creating...' : 'Create Store'}
              </button>
            </div>
          </form>
        )}
      </Modal>

      {/* Store Details Slide-over / Modal */}
      <Modal
        isOpen={Boolean(selectedStore)}
        onClose={() => {
          setSelectedStore(null);
          setStoreDetails(null);
        }}
        maxWidth="640px"
        title={storeDetails?.name || 'Store Configuration'}
        subtitle={`Store ID: ${storeDetails?.id || ''}`}
      >
        {loadingDetails ? (
          <div style={{ textAlign: 'center', padding: '40px 0', color: 'var(--text-muted)' }}>
            Loading store profile...
          </div>
        ) : storeDetails ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
            {/* Header info */}
            <div style={{ padding: '16px', background: 'var(--bg-canvas)', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-subtle)' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <div>
                  <h4 style={{ fontSize: '16px', fontWeight: '700', color: 'var(--brand-dark)' }}>
                    {storeDetails.name}
                  </h4>
                  <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '2px' }}>
                    {storeDetails.email || 'No contact email configured'}
                  </p>
                </div>
                <Badge status={storeDetails.status} />
              </div>

              {/* POS Key section */}
              <div style={{ marginTop: '14px', paddingTop: '12px', borderTop: '1px solid var(--border-light)' }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '6px' }}>
                  <span style={{ fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)' }}>
                    POS Machine Integration Key
                  </span>
                  <button
                    type="button"
                    onClick={() => handleRegenerateKey(storeDetails.id)}
                    style={{ fontSize: '11px', color: 'var(--brand-teal)', background: 'none', border: 'none', cursor: 'pointer', fontWeight: '600' }}
                  >
                    Regenerate Key
                  </button>
                </div>

                {storeDetails.raw_api_key ? (
                  <div style={{ display: 'flex', gap: '8px' }}>
                    <input
                      type="text"
                      readOnly
                      className="input-control font-mono"
                      value={storeDetails.raw_api_key}
                      style={{ fontSize: '11px' }}
                    />
                    <button
                      type="button"
                      onClick={() => copyToClipboard(storeDetails.raw_api_key)}
                      className="btn btn-secondary btn-sm"
                    >
                      <Copy size={14} />
                      <span>Copy</span>
                    </button>
                  </div>
                ) : (
                  <div style={{ fontSize: '12px', color: 'var(--text-muted)', background: 'var(--bg-surface)', padding: '8px 12px', borderRadius: 'var(--radius-xs)', border: '1px solid var(--border-light)', display: 'flex', justifyContent: 'space-between' }}>
                    <span>{storeDetails.has_api_key ? '●●●●●●●●●● (Key is securely hashed)' : 'No active POS key'}</span>
                  </div>
                )}
              </div>
            </div>

            {/* Active Deals Section */}
            <div>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '12px' }}>
                <h4 style={{ fontSize: '14px', fontWeight: '700', color: 'var(--brand-dark)', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                  Active Deals ({storeDetails.offers?.length || 0})
                </h4>
                <button
                  type="button"
                  onClick={() => setIsAddDealOpen(true)}
                  className="btn btn-secondary btn-sm"
                >
                  <Plus size={14} />
                  <span>Add Deal</span>
                </button>
              </div>

              {storeDetails.offers && storeDetails.offers.length > 0 ? (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  {storeDetails.offers.map((deal) => (
                    <div
                      key={deal.id}
                      style={{
                        padding: '12px 16px',
                        background: 'var(--bg-canvas)',
                        borderRadius: 'var(--radius-sm)',
                        border: '1px solid var(--border-subtle)',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                      }}
                    >
                      <div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <h5 style={{ fontSize: '13px', fontWeight: '700', color: 'var(--text-primary)' }}>
                            {deal.title}
                          </h5>
                          <Badge status={deal.status} />
                        </div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '12px', marginTop: '4px' }}>
                          <span style={{ fontWeight: '700', color: 'var(--brand-teal)', fontFamily: 'monospace' }}>
                            {deal.discount_type === 'PERCENT' ? `${deal.discount_value}% OFF` : `$${deal.discount_value} OFF`}
                          </span>
                          <span style={{ color: 'var(--text-subtle)' }}>&bull;</span>
                          <span style={{ color: 'var(--text-muted)', fontWeight: '600' }}>
                            {deal.points_cost} Points
                          </span>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div style={{ textAlign: 'center', padding: '24px', background: 'var(--bg-canvas)', borderRadius: 'var(--radius-sm)', border: '1px dashed var(--border-light)', fontSize: '12px', color: 'var(--text-muted)' }}>
                  No deals configured for this store yet.
                </div>
              )}
            </div>

            {/* Recent Redemptions */}
            <div>
              <h4 style={{ fontSize: '14px', fontWeight: '700', color: 'var(--brand-dark)', textTransform: 'uppercase', letterSpacing: '0.04em', marginBottom: '10px' }}>
                Store Redemptions History
              </h4>
              {storeDetails.recent_redemptions && storeDetails.recent_redemptions.length > 0 ? (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  {storeDetails.recent_redemptions.map((r) => (
                    <div
                      key={r.id}
                      style={{
                        padding: '8px 12px',
                        background: 'var(--bg-canvas)',
                        borderRadius: 'var(--radius-xs)',
                        border: '1px solid var(--border-subtle)',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                        fontSize: '12px',
                      }}
                    >
                      <div>
                        <span className="font-mono" style={{ fontWeight: '700', color: 'var(--brand-dark)' }}>
                          {r.short_code}
                        </span>
                        <span style={{ color: 'var(--text-muted)', marginLeft: '8px' }}>
                          {r.offer_title}
                        </span>
                      </div>
                      <span style={{ fontWeight: '700', color: 'var(--brand-teal)', fontFamily: 'monospace' }}>
                        +${(r.discount_value || 0).toFixed(2)}
                      </span>
                    </div>
                  ))}
                </div>
              ) : (
                <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                  No customer redemptions recorded for this store yet.
                </p>
              )}
            </div>
          </div>
        ) : null}
      </Modal>

      {/* Add Deal Modal for Store */}
      <Modal
        isOpen={isAddDealOpen}
        onClose={() => setIsAddDealOpen(false)}
        title={`Add Deal for ${storeDetails?.name || 'Store'}`}
        subtitle="Configure discount rate, point redemption requirement, and stock limit."
      >
        <form onSubmit={handleCreateDealForStore} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
          <div>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '4px' }}>
              Deal Campaign Title *
            </label>
            <input
              type="text"
              required
              className="input-control"
              placeholder="e.g. 20% Off Entire Summer Menu"
              value={dealForm.title}
              onChange={(e) => setDealForm({ ...dealForm, title: e.target.value })}
            />
          </div>

          <div>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '4px' }}>
              Description / Terms
            </label>
            <input
              type="text"
              className="input-control"
              placeholder="Valid on dine-in and takeaway orders"
              value={dealForm.description}
              onChange={(e) => setDealForm({ ...dealForm, description: e.target.value })}
            />
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '4px' }}>
                Discount Type
              </label>
              <select
                className="input-control"
                value={dealForm.discount_type}
                onChange={(e) => setDealForm({ ...dealForm, discount_type: e.target.value })}
              >
                <option value="PERCENT">Percentage (%)</option>
                <option value="FIXED">Fixed Amount ($)</option>
              </select>
            </div>

            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '4px' }}>
                Discount Value *
              </label>
              <input
                type="number"
                required
                min="1"
                className="input-control"
                value={dealForm.discount_value}
                onChange={(e) => setDealForm({ ...dealForm, discount_value: e.target.value })}
              />
            </div>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '4px' }}>
                Points Cost *
              </label>
              <input
                type="number"
                required
                min="10"
                className="input-control"
                value={dealForm.points_cost}
                onChange={(e) => setDealForm({ ...dealForm, points_cost: e.target.value })}
              />
            </div>

            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '4px' }}>
                Inventory Limit
              </label>
              <input
                type="number"
                min="0"
                className="input-control"
                placeholder="Unlimited"
                value={dealForm.inventory}
                onChange={(e) => setDealForm({ ...dealForm, inventory: e.target.value })}
              />
            </div>
          </div>

          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '16px' }}>
            <button
              type="button"
              onClick={() => setIsAddDealOpen(false)}
              className="btn btn-ghost"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmittingDeal}
              className="btn btn-primary"
            >
              {isSubmittingDeal ? 'Publishing...' : 'Publish Deal'}
            </button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
