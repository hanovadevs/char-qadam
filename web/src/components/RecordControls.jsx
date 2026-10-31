import React from 'react';
export default function RecordControls({ page, setPage, hasMore, loading }) {
  return <nav aria-label="Record pages" style={{ display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 12, marginTop: 16 }}>
    <button className="btn btn-secondary btn-sm" disabled={loading || !page} onClick={() => setPage(page - 1)}>Previous</button>
    <span>Page {page + 1}</span>
    <button className="btn btn-secondary btn-sm" disabled={loading || !hasMore} onClick={() => setPage(page + 1)}>Next</button>
  </nav>;
}
