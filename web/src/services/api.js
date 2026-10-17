// Stepsy Admin API Client

const BASE_URL = import.meta.env.VITE_API_URL || '';

class ApiClient {
  constructor() {
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

  async request(path, options = {}) {
    const url = `${BASE_URL}${path}`;
    const headers = { ...this.getHeaders(), ...options.headers };

    try {
      const response = await fetch(url, { ...options, headers });
      if (response.status === 401) {
        this.setToken(null);
        if (!window.location.pathname.includes('/login')) {
          window.location.href = '/login';
        }
        throw new Error('Session expired. Please log in again.');
      }

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.detail || errorData.message || `Request failed with status ${response.status}`);
      }

      return await response.json();
    } catch (err) {
      console.error(`[API Error] ${path}:`, err);
      throw err;
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

  async getConfig() {
    return this.request('/admin/config');
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

  async deletePartner(partnerId) {
    return this.request(`/admin/partners/${partnerId}`, {
      method: 'DELETE',
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
    if (search) params.append('search', search);
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

  async listRedemptions() {
    return this.request('/admin/redemptions');
  }

  async updateVoucher(voucherId, payload) {
    return this.request(`/admin/vouchers/${voucherId}`, {
      method: 'PATCH',
      body: JSON.stringify(payload),
    });
  }

  async deleteVoucher(voucherId) {
    return this.request(`/admin/vouchers/${voucherId}`, {
      method: 'DELETE',
    });
  }

  // Users
  async listUsers({ search, status } = {}) {
    const params = new URLSearchParams();
    if (search) params.append('search', search);
    if (status && status !== 'ALL') params.append('status', status);
    const query = params.toString() ? `?${params.toString()}` : '';
    return this.request(`/admin/users${query}`);
  }

  async updateUser(userId, payload) {
    return this.request(`/admin/users/${userId}`, {
      method: 'PATCH',
      body: JSON.stringify(payload),
    });
  }

  async deleteUser(userId) {
    return this.request(`/admin/users/${userId}`, {
      method: 'DELETE',
    });
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

  async getUserActivity(userId, range = 'month') {
    return this.request(`/admin/users/${userId}/activity?range=${range}`);
  }

  // Ledger & Audit
  async getGlobalLedger({ reason } = {}) {
    const params = new URLSearchParams();
    if (reason && reason !== 'ALL') params.append('reason', reason);
    const query = params.toString() ? `?${params.toString()}` : '';
    return this.request(`/admin/ledger${query}`);
  }

  async getAuditLogs() {
    return this.request('/admin/audit-logs');
  }
}

export const api = new ApiClient();
