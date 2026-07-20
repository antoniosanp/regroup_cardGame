// Backend endpoint resolution for a device/emulator: "localhost" on Android
// means the phone itself, so the Android emulator reaches the dev machine via
// its magic 10.0.2.2 alias. A real phone on the same Wi-Fi needs the dev
// machine's LAN IP — set it here (or via app.json "extra") when testing on
// hardware.

import Constants from 'expo-constants';
import { Platform } from 'react-native';

interface Extra {
  backendUrl?: string;
}

export function backendHttpUrl(): string {
  const extra = (Constants.expoConfig?.extra ?? {}) as Extra;
  if (extra.backendUrl) return extra.backendUrl;
  // Expo dev mode: derive the dev machine's LAN address from the bundler host
  // so a physical phone works out of the box.
  const hostUri = Constants.expoConfig?.hostUri;
  if (hostUri) {
    const host = hostUri.split(':')[0];
    if (host && host !== 'localhost' && host !== '127.0.0.1') {
      return `http://${host}:8080`;
    }
  }
  return Platform.OS === 'android' ? 'http://10.0.2.2:8080' : 'http://localhost:8080';
}

export function backendWsUrl(): string {
  return backendHttpUrl().replace(/^http/, 'ws') + '/ws';
}
