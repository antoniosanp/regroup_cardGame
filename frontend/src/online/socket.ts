// Thin abstraction over @stomp/stompjs so the online store can be driven by a
// fake socket in tests (no live backend needed to verify the contract) and so
// the transport can be swapped later (e.g. for a Flutter-parity client).

import { Client } from '@stomp/stompjs';
import { backendWsUrl } from './api';

export interface GameSocketHandlers {
  /** Fired on every successful (re)connect. */
  onConnect: () => void;
  /** Fired when the underlying socket drops; the client keeps retrying. */
  onDisconnect: () => void;
  onPrivateMessage: (raw: unknown) => void;
  onMatchMessage: (raw: unknown) => void;
}

export interface GameSocket {
  activate(token: string, handlers: GameSocketHandlers): void;
  /** Subscribe /topic/match.{matchId}; re-subscribed automatically after reconnect. */
  subscribeMatch(matchId: string): void;
  unsubscribeMatch(): void;
  publish(destination: string, body: unknown): void;
  deactivate(): void;
}

export type GameSocketFactory = () => GameSocket;

export class StompGameSocket implements GameSocket {
  private client: Client | null = null;
  private handlers: GameSocketHandlers | null = null;
  private matchId: string | null = null;

  activate(token: string, handlers: GameSocketHandlers): void {
    this.handlers = handlers;
    this.client = new Client({
      brokerURL: backendWsUrl(),
      connectHeaders: { token },
      reconnectDelay: 2000,
      onConnect: () => {
        this.subscribePrivate();
        if (this.matchId) this.doSubscribeMatch(this.matchId);
        handlers.onConnect();
      },
      onWebSocketClose: () => handlers.onDisconnect(),
    });
    this.client.activate();
  }

  private subscribePrivate(): void {
    this.client?.subscribe('/user/queue/game', (frame) => {
      this.handlers?.onPrivateMessage(safeJson(frame.body));
    });
  }

  private doSubscribeMatch(matchId: string): void {
    this.client?.subscribe(`/topic/match.${matchId}`, (frame) => {
      this.handlers?.onMatchMessage(safeJson(frame.body));
    });
  }

  subscribeMatch(matchId: string): void {
    if (this.matchId === matchId) return;
    this.matchId = matchId;
    if (this.client?.connected) this.doSubscribeMatch(matchId);
  }

  unsubscribeMatch(): void {
    this.matchId = null;
  }

  publish(destination: string, body: unknown): void {
    this.client?.publish({ destination, body: JSON.stringify(body) });
  }

  deactivate(): void {
    this.matchId = null;
    void this.client?.deactivate();
    this.client = null;
  }
}

function safeJson(body: string): unknown {
  try {
    return JSON.parse(body);
  } catch {
    return null;
  }
}
