import React from 'react';

export default function Badge({ status, label }) {
  const norm = (status || '').toUpperCase();
  const text = label || status || 'UNKNOWN';

  let className = 'badge badge-neutral';

  if (['ACTIVE', 'SUCCESS', 'REDEEMED', 'COMPLETED', 'LIVE'].includes(norm)) {
    className = 'badge badge-active';
  } else if (['PENDING', 'WARNING', 'ISSUED', 'EXPIRING'].includes(norm)) {
    className = 'badge badge-pending';
  } else if (['INACTIVE', 'EXPIRED', 'SUSPENDED', 'FAILED', 'FLAGGED'].includes(norm)) {
    className = 'badge badge-inactive';
  }

  return <span className={className}>{text}</span>;
}
