// Run only against a dedicated staging database containing test accounts.
// USERS_FILE is a local JSON array of {token,user_id}; never commit this file.
import http from 'k6/http';
import { check, sleep } from 'k6';
import { SharedArray } from 'k6/data';
import exec from 'k6/execution';
const users = new SharedArray('users', () => JSON.parse(open(__ENV.USERS_FILE)));
const base = __ENV.BASE_URL;
if (!base || users.length < Number(__ENV.VUS || 100)) throw new Error('BASE_URL and enough unique test users are required');
export const options = {
  stages: [
    { duration: '1m', target: Number(__ENV.VUS || 100) },
    { duration: '5m', target: Number(__ENV.VUS || 100) },
    { duration: '1m', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<500', 'p(99)<1500'],
    checks: ['rate>0.99'],
  },
};
export default function () {
  const user = users[(exec.vu.idInTest - 1) % users.length];
  const params = { headers: { Authorization: `Bearer ${user.token}` } };
  const paths = ['/auth/me', '/points/balance', '/activity?range=week', '/offers?limit=20', '/leaderboard?scope=week&limit=20'];
  const path = paths[Math.floor(Math.random() * paths.length)];
  const res = http.get(`${base}${path}`, params);
  check(res, { 'authenticated read succeeds': r => r.status === 200 });
  // Simulates clients syncing at most once per minute with isolated test users.
  if (__ITER % 12 === 0) {
    const date = new Date().toISOString().slice(0, 10);
    const sync = http.post(`${base}/activity/sync`, JSON.stringify({
      local_date: date, eligible_steps: Math.min(20000, (__ITER + 1) * 10),
      source: 'health', sync_key: `load-${exec.scenario.startTime}-${exec.vu.idInTest}-${__ITER}`,
    }), { headers: { ...params.headers, 'Content-Type': 'application/json' } });
    check(sync, { 'sync succeeds': r => r.status === 200 });
  }
  sleep(5 + Math.random() * 2);
}
