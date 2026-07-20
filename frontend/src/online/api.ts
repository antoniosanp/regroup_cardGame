// Guest identity per WS_CONTRACT.md: POST /api/players {name} -> {playerId, token,
// name}. Persist in localStorage so the token can be replayed on STOMP CONNECT
// for reconnection. No accounts / login / JWT — just a name.

export interface Identity {
  playerId: string;
  token: string;
  name: string;
}

const STORAGE_KEY = 'regroup.identity';

export function backendHttpUrl(): string {
  return (import.meta.env.VITE_BACKEND_URL as string | undefined) ?? 'http://localhost:8080';
}

export function backendWsUrl(): string {
  return backendHttpUrl().replace(/^http/, 'ws') + '/ws';
}

export async function registerPlayer(name: string): Promise<Identity> {
  const res = await fetch(`${backendHttpUrl()}/api/players`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name }),
  });
  if (!res.ok) throw new Error(`Registration failed (${res.status})`);
  const data: unknown = await res.json();
  if (
    typeof data !== 'object' ||
    data === null ||
    typeof (data as Identity).playerId !== 'string' ||
    typeof (data as Identity).token !== 'string'
  ) {
    throw new Error('Registration returned an unexpected payload');
  }
  const { playerId, token } = data as Identity;
  return { playerId, token, name };
}

export function loadIdentity(): Identity | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Identity;
    if (parsed && parsed.playerId && parsed.token) return parsed;
    return null;
  } catch {
    return null;
  }
}

export function saveIdentity(identity: Identity): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(identity));
}

export function clearIdentity(): void {
  localStorage.removeItem(STORAGE_KEY);
}
