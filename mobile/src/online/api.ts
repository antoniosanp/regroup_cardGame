// Guest identity per WS_CONTRACT.md: POST /api/players {name} -> {playerId,
// token, name}. Persisted in AsyncStorage (the RN counterpart of the web
// client's localStorage) so the token can be replayed on STOMP CONNECT for
// reconnection. No accounts / login / JWT — just a name.

import AsyncStorage from '@react-native-async-storage/async-storage';
import { backendHttpUrl } from './config';

export interface Identity {
  playerId: string;
  token: string;
  name: string;
}

const STORAGE_KEY = 'regroup.identity';

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

export async function loadIdentity(): Promise<Identity | null> {
  try {
    const raw = await AsyncStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Identity;
    if (parsed && parsed.playerId && parsed.token) return parsed;
    return null;
  } catch {
    return null;
  }
}

export async function saveIdentity(identity: Identity): Promise<void> {
  await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(identity));
}

export async function clearIdentity(): Promise<void> {
  await AsyncStorage.removeItem(STORAGE_KEY);
}
