import { useCallback, useEffect, useRef, useState } from 'react';
import { api } from '../services/api.js';

export function useAdminQuery(path, initialData = null) {
  const cached = api.cache.peek(path);
  const [state, setState] = useState(() => ({ path, data: cached?.data, hasData: Boolean(cached), busy: !cached, error: null }));
  const requestId = useRef(0);
  const active = useRef(false);
  const refresh = useCallback(async () => {
    const id = ++requestId.current;
    const saved = api.cache.peek(path);
    setState((previous) => previous.path === path
      ? { ...previous, busy: true, error: null }
      : { path, data: saved?.data, hasData: Boolean(saved), busy: true, error: null });
    try {
      const data = await api.request(path);
      if (active.current && id === requestId.current) setState({ path, data, hasData: true, busy: false, error: null });
      return data;
    } catch (error) {
      if (active.current && id === requestId.current) setState((previous) => ({ ...previous, busy: false, error: error.message }));
      return undefined;
    }
  }, [path]);

  useEffect(() => {
    active.current = true;
    const saved = api.cache.peek(path);
    if (saved) setState({ path, data: saved.data, hasData: true, busy: false, error: null });
    if (!api.cache.isFresh(path)) refresh();
    const revalidate = () => {
      if (document.visibilityState === 'visible' && !api.cache.isFresh(path)) refresh();
    };
    const timer = setInterval(() => {
      if (api.token && document.visibilityState === 'visible') refresh();
    }, 30000);
    window.addEventListener('focus', revalidate);
    document.addEventListener('visibilitychange', revalidate);
    const unsubscribe = api.cache.subscribe(() => { if (api.token) refresh(); });
    return () => {
      active.current = false;
      requestId.current++;
      clearInterval(timer);
      window.removeEventListener('focus', revalidate);
      document.removeEventListener('visibilitychange', revalidate);
      unsubscribe();
    };
  }, [path, refresh]);

  const current = state.path === path ? state : { data: cached?.data, hasData: Boolean(cached), busy: !cached, error: null };
  return { data: current.hasData ? current.data : initialData, loading: current.busy && !current.hasData,
    isRefreshing: current.busy, error: current.error, refresh };
}

export function useDebouncedValue(value, delay = 250) {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);
  return debounced;
}
