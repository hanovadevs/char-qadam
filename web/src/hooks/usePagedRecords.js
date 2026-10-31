import { useEffect, useState } from 'react';

export function usePagedRecords(load, filters) {
  const key = JSON.stringify(filters);
  const [position, setPosition] = useState({ key, page: 0 });
  const page = position.key === key ? position.page : 0;
  const [revision, setRevision] = useState(0);
  const [state, setState] = useState({ rows: [], hasMore: false, loading: true, error: '' });
  useEffect(() => {
    let active = true;
    setState(previous => ({ ...previous, loading: true, error: '' }));
    const timer = setTimeout(async () => {
      try {
        const rows = await load({ ...JSON.parse(key), limit: 51, offset: page * 50 });
        if (active) setState({ rows: rows.slice(0, 50), hasMore: rows.length > 50, loading: false, error: '' });
      } catch (err) {
        if (active) setState(previous => ({ ...previous, loading: false, error: err.message }));
      }
    }, 250);
    return () => { active = false; clearTimeout(timer); };
  }, [load, key, page, revision]);
  return { ...state, page, setPage: value => setPosition({ key, page: value }), refresh: () => setRevision(v => v + 1) };
}
