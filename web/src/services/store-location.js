export function googleMapsLink(value) {
  if (!value?.trim()) return null;
  try {
    const raw = value.trim();
    const uri = new URL(raw);
    const host = uri.hostname.toLowerCase();
    const maps = ['maps.app.goo.gl', 'maps.google.com', 'maps.google.com.pk'].includes(host)
      || (host === 'goo.gl' && uri.pathname.startsWith('/maps'))
      || (['google.com', 'www.google.com', 'google.com.pk', 'www.google.com.pk'].includes(host)
        && (uri.pathname === '/maps' || uri.pathname.startsWith('/maps/')));
    if (raw.length <= 2048 && uri.protocol === 'https:' && maps
      && !uri.username && !uri.password && !/^https:\/\/[^/?#]*:/i.test(raw)) return raw;
  } catch { /* Invalid or unsupported destinations have no external action. */ }
  return null;
}

export function apiErrorMessage(data, status) {
  if (Array.isArray(data?.detail)) {
    return data.detail.map((error) => error.msg || 'Check the form fields.').join(' ');
  }
  return typeof data?.detail === 'string' ? data.detail
    : typeof data?.message === 'string' ? data.message : `Request failed with status ${status}`;
}
