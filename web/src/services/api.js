// Stepsy Admin API Client

const BASE_URL = import.meta.env?.VITE_API_URL || '';

class ApiClient {
  constructor() {
    this.inflight = new Map();
    this.token = localStorage.getItem('stepsy_admin_token') || null;
  }

  setToken(token) {
    this.token = token;
    if (token) {
      localStorage.setItem('stepsy_admin_token', token);
    } else {
      localStorage.removeItem('stepsy_admin_token');
    }
  }

  getHeaders() {
    const headers = {
      'Content-Type': 'application/json',
    };
    if (this.token) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }
    return headers;
  }

  request(path, options = {}) {
    const key = `${this.token || ''}:${path}`;
    const share = (!options.method || options.method === 'GET') && !options.signal;
    if (share && this.inflight.has(key)) return this.inflight.get(key);
    const request = this.performRequest(path, options);
    if (share) {
      this.inflight.set(key, request);
      const clear = () => {
        if (this.inflight.get(key) === request) this.inflight.delete(key);
      };
      request.then(clear, clear);
    }
    return request;
  }

  async performRequest(path, options = {}) {
    const requestToken = this.token;
    const url = `${BASE_URL}${path}`;
    const headers = { ...this.getHeaders(), ...options.headers };

    const controller = new AbortController();
    const abort = () => controller.abort();
    options.signal?.addEventListener('abort', abort, { once: true });
    if (options.signal?.aborted) controller.abort();
    const timeout = setTimeout(abort, 15000);
    try {
      const response = await fetch(url, { ...options, headers, signal: controller.signal });
      if (response.status === 401 && this.token === requestToken) {
        this.setToken(null);
        if (!window.location.pathname.includes('/login')) {
          window.location.href = '/login';
        }
        throw new Error('Session expired. Please log in again.');
      }

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        const detail = Array.isArray(errorData.detail)
          ? errorData.detail.map(item => item.msg).join('; ')
          : errorData.detail || errorData.message;
        throw new Error(detail || `Request failed with status ${response.status}`);
      }

      return response.status === 204 ? null : await response.json();
    } catch (err) {
      console.error(`[API Error] ${path}:`, err);
      throw err;
    } finally {
      clearTimeout(timeout);
      options.signal?.removeEventListener('abort', abort);
    }
  }

  // Auth
  async login(email, password) {
    const data = await this.request('/admin/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    });
    if (data && data.access_token) {
      this.setToken(data.access_token);
    }
    return data;
  }

  async getMe() {
    return this.request('/admin/auth/me');
  }

  logout() {
    this.setToken(null);
    window.location.href = '/login';
  }

  // Overview & Analytics
  async getAnalyticsOverview() {
    return this.request('/admin/analytics/overview');
  }

  async getAnalyticsCharts() {
    return this.request('/admin/analytics/charts');
  }

  // Partners / Stores
  async listPartners({ search, status } = {}) {
    const params = new URLSearchParams();
    if (search) params.append('search', search);
    if (status && status !== 'ALL') params.append('status', status);
    const query = params.toString() ? `?${params.toString()}` : '';
    return this.request(`/admin/partners${query}`);
  }

  async getPartner(partnerId) {
    return this.request(`/admin/partners/${partnerId}`);
  }

  async createPartner(payload) {
    return this.request('/admin/partners', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }

  async updatePartner(partnerId, payload) {
    return this.request(`/admin/partners/${partnerId}`, {
      method: 'PATCH',
      body: JSON.stringify(payload),
    });
  }

  async regeneratePartnerKey(partnerId) {
    return this.request(`/admin/partners/${partnerId}/regenerate-key`, {
      method: 'POST',
    });
  }

  async resetPartnerPassword(partnerId, password) {
    return this.request(`/admin/partners/${partnerId}/reset-password`, {
      method: 'POST',
      body: JSON.stringify({ password }),
    });
  }

  // Deals / Offers
  async listOffers({ partner_id, status, search } = {}) {
    const params = new URLSearchParams();
    if (partner_id && partner_id !== 'ALL') params.append('partner_id', partner_id);
    if (status && status !== 'ALL') params.append('status', status);
    if (search) params.append('search', search);
    const query = params.toString() ? `?${params.toString()}` : '';
    return this.request(`/admin/offers${query}`);
  }

  async createOffer(payload) {
    return this.request('/admin/offers', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }

  async updateOffer(offerId, payload) {
    return this.request(`/admin/offers/${offerId}`, {
      method: 'PATCH',
      body: JSON.stringify(payload),
    });
  }

  async deleteOffer(offerId) {
    return this.request(`/admin/offers/${offerId}`, {
      method: 'DELETE',
    });
  }

  // Vouchers & POS
  async listVouchers({ search, status } = {}) {
    const params = new URLSearchParams();
    if (search) params.append('short_code', search);
    if (status && status !== 'ALL') params.append('status', status);
    const query = params.toString() ? `?${params.toString()}` : '';
    return this.request(`/admin/vouchers${query}`);
  }

  async lookupVoucher(short_code) {
    return this.request('/admin/vouchers/lookup', {
      method: 'POST',
      body: JSON.stringify({ short_code }),
    });
  }

  async redeemVoucher({ short_code, order_reference, store_id } = {}) {
    return this.request('/admin/vouchers/redeem', {
      method: 'POST',
      body: JSON.stringify({ short_code, order_reference, store_id }),
    });
  }

  async listRedemptions({ limit = 50 } = {}) {
    return this.request(`/admin/redemptions?limit=${limit}`);
  }

  // Users
  async listUsers({ search, status, limit = 51, offset = 0 } = {}) {
    const params = new URLSearchParams({ limit: String(limit), offset: String(offset) });
    if (search) params.append('search', search);
    if (status && status !== 'ALL') params.append('status', status);
    const query = params.toString() ? `?${params.toString()}` : '';
    return this.request(`/admin/users${query}`);
  }

  async updateUserStatus(userId, status) {
    return this.request(`/admin/users/${userId}/status`, {
      method: 'PATCH',
      body: JSON.stringify({ status }),
    });
  }

  async adjustUserPoints(userId, { delta, reason_note }) {
    return this.request(`/admin/users/${userId}/adjust-points`, {
      method: 'POST',
      body: JSON.stringify({ delta, reason_note }),
    });
  }

  async getUserLedger(userId) {
    return this.request(`/admin/users/${userId}/ledger`);
  }

  // Ledger & Audit
  async getGlobalLedger({ reason, limit = 51, offset = 0 } = {}) {
    const params = new URLSearchParams({ limit: String(limit), offset: String(offset) });
    if (reason && reason !== 'ALL') params.append('reason', reason);
    return this.request(`/admin/ledger?${params}`);
  }

  async getAuditLogs({ action, actor, limit = 51, offset = 0 } = {}) {
    const params = new URLSearchParams({ limit: String(limit), offset: String(offset) });
    if (action) params.append('action', action);
    if (actor) params.append('actor', actor);
    return this.request(`/admin/audit-logs?${params}`);
  }

  getSystemStatus() { return this.request('/admin/system'); }
  getLedgerSummary() { return this.request('/admin/ledger/summary'); }
  expireVouchers() { return this.request('/admin/vouchers/sweep-expired', { method: 'POST' }); }
}

export const api = new ApiClient();
