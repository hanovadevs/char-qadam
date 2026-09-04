import React, { useState, useEffect } from 'react';
import { api } from '../services/api';
import Modal from '../components/Modal';
import Badge from '../components/Badge';
import { Search, Plus, Trash2 } from 'lucide-react';

export default function Deals() {
  const [deals, setDeals] = useState([]);
  const [partners, setPartners] = useState([]);
  const [search, setSearch] = useState('');
  const [partnerFilter, setPartnerFilter] = useState('ALL');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Create Deal Modal
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [dealForm, setDealForm] = useState({
    partner_id: '',
    title: '',
    description: '',
    discount_type: 'PERCENT',
    discount_value: 15,
    points_cost: 200,
    min_basket: 0,
    inventory: 100,
    status: 'ACTIVE',
  });
  const [isSubmitting, setIsSubmitting] = useState(false);

  const fetchData = async () => {
    setLoading(true);
    setError(null);
    try {
      const [dealsData, partnersData] = await Promise.all([
        api.listOffers({
          search: search.trim() || undefined,
          partner_id: partnerFilter !== 'ALL' ? partnerFilter : undefined,
          status: statusFilter !== 'ALL' ? statusFilter : undefined,
        }),
        api.listPartners(),
      ]);
      setDeals(dealsData || []);
      setPartners(partnersData || []);
    } catch (err) {
      setError(err.message || 'Failed to load deals.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [search, partnerFilter, statusFilter]);

  const handleCreateDeal = async (e) => {
    e.preventDefault();
    if (!dealForm.partner_id || !dealForm.title.trim()) return;

    setIsSubmitting(true);
    try {
      await api.createOffer({
        partner_id: dealForm.partner_id,
        title: dealForm.title.trim(),
        description: dealForm.description.trim() || undefined,
        discount_type: dealForm.discount_type,
        discount_value: Number(dealForm.discount_value),
        points_cost: Number(dealForm.points_cost),
        min_basket: dealForm.min_basket ? Number(dealForm.min_basket) : undefined,
        inventory: dealForm.inventory ? Number(dealForm.inventory) : undefined,
        status: dealForm.status,
      });
      setIsCreateOpen(false);
      fetchData();
    } catch (err) {
      alert(err.message || 'Failed to create deal.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDeleteDeal = async (dealId) => {
    if (!window.confirm('Are you sure you want to remove this deal?')) return;
    try {
      await api.deleteOffer(dealId);
      fetchData();
    } catch (err) {
      alert(err.message || 'Failed to delete deal.');
    }
  };

  return (
    <div className="container-main">
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '24px', flexWrap: 'wrap', gap: '16px' }}>
        <div>
          <h1 style={{ fontSize: '26px', fontWeight: '800', color: 'var(--brand-dark)' }}>
            Deals & Offers
          </h1>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
            Publish discount campaigns, set point redemption pricing, and manage partner deals.
          </p>
        </div>

        <button
          onClick={() => {
            setDealForm({
              partner_id: partners[0]?.id || '',
              title: '',
              description: '',
              discount_type: 'PERCENT',
              discount_value: 15,
              points_cost: 200,
              min_basket: 0,
              inventory: 100,
              status: 'ACTIVE',
            });
            setIsCreateOpen(true);
          }}
          className="btn btn-primary"
        >
          <Plus size={16} />
          <span>Publish New Deal</span>
        </button>
      </div>

      {/* Filter controls */}
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
        <div style={{ display: 'flex', gap: '12px', flex: 1, minWidth: '280px' }}>
          <div style={{ position: 'relative', width: '280px' }}>
            <Search
              size={16}
              style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-subtle)' }}
            />
            <input
              type="text"
              className="input-control"
              style={{ paddingLeft: '36px' }}
              placeholder="Search deals..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          <select
            className="input-control"
            style={{ width: '200px' }}
            value={partnerFilter}
            onChange={(e) => setPartnerFilter(e.target.value)}
          >
            <option value="ALL">All Stores</option>
            {partners.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </select>
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

      {/* Deals Grid */}
      {loading ? (
        <div style={{ textAlign: 'center', padding: '60px 0', color: 'var(--text-muted)', fontSize: '13px' }}>
          Loading deals catalog...
        </div>
      ) : deals.length === 0 ? (
        <div className="stepsy-card" style={{ textAlign: 'center', padding: '48px 24px' }}>
          <h3 style={{ fontSize: '16px', fontWeight: '700', color: 'var(--text-primary)' }}>
            No Deals Published
          </h3>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
            Click "Publish New Deal" to launch an offer for any partner store.
          </p>
        </div>
      ) : (
        <div className="grid-cols-3">
          {deals.map((d) => (
            <div
              key={d.id}
              className="stepsy-card"
              style={{
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'space-between',
              }}
            >
              <div>
                <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: '12px' }}>
                  <span
                    style={{
                      fontSize: '11px',
                      fontWeight: '700',
                      textTransform: 'uppercase',
                      letterSpacing: '0.04em',
                      color: 'var(--brand-teal)',
                      background: 'var(--tint-mint-subtle)',
                      padding: '2px 8px',
                      borderRadius: 'var(--radius-full)',
                    }}
                  >
                    {d.partner_name || 'Partner Store'}
                  </span>
                  <Badge status={d.status} />
                </div>

                <h3 style={{ fontSize: '16px', fontWeight: '700', color: 'var(--text-primary)', marginBottom: '6px' }}>
                  {d.title}
                </h3>
                {d.description && (
                  <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '16px', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>
                    {d.description}
                  </p>
                )}

                <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '14px' }}>
                  <span style={{ fontSize: '18px', fontWeight: '800', color: 'var(--brand-dark)', fontFamily: 'monospace' }}>
                    {d.discount_type === 'PERCENT' ? `${d.discount_value}% OFF` : `$${d.discount_value} OFF`}
                  </span>
                  <span style={{ fontSize: '13px', fontWeight: '600', color: 'var(--brand-teal)', background: 'var(--bg-canvas)', padding: '3px 8px', borderRadius: 'var(--radius-xs)' }}>
                    {d.points_cost} Points
                  </span>
                </div>

                {d.inventory != null && (
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                    Inventory: <strong>{d.inventory} available</strong>
                  </div>
                )}
              </div>

              <div style={{ marginTop: '18px', paddingTop: '12px', borderTop: '1px solid var(--border-subtle)', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <span style={{ fontSize: '11px', color: 'var(--text-subtle)' }}>
                  ID: {d.id.slice(0, 8)}
                </span>
                <button
                  onClick={() => handleDeleteDeal(d.id)}
                  className="btn btn-ghost btn-sm"
                  style={{ color: '#BE123C', padding: '4px 8px' }}
                  title="Remove Deal"
                >
                  <Trash2 size={14} />
                  <span>Remove</span>
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Create Deal Modal */}
      <Modal
        isOpen={isCreateOpen}
        onClose={() => setIsCreateOpen(false)}
        title="Publish New Deal Campaign"
        subtitle="Configure the discount incentive and point redemption requirement."
      >
        <form onSubmit={handleCreateDeal} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
          <div>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '4px' }}>
              Target Partner Store *
            </label>
            <select
              required
              className="input-control"
              value={dealForm.partner_id}
              onChange={(e) => setDealForm({ ...dealForm, partner_id: e.target.value })}
            >
              <option value="" disabled>Select a partner store...</option>
              {partners.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '4px' }}>
              Campaign Title *
            </label>
            <input
              type="text"
              required
              className="input-control"
              placeholder="e.g. 20% Off Footwear Collection"
              value={dealForm.title}
              onChange={(e) => setDealForm({ ...dealForm, title: e.target.value })}
            />
          </div>

          <div>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '4px' }}>
              Terms & Conditions / Description
            </label>
            <input
              type="text"
              className="input-control"
              placeholder="Valid on orders over $50"
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
              onClick={() => setIsCreateOpen(false)}
              className="btn btn-ghost"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className="btn btn-primary"
            >
              {isSubmitting ? 'Publishing...' : 'Publish Deal'}
            </button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
