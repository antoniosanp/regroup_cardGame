// In-memory stand-in for StompGameSocket. It never touches the network: every publish is
// routed to the driver, which decides what the "server" says back. Because the online store
// only ever sees GameSocket, it runs its genuine code paths against this — real busy
// transitions, real mergePoints/rotateCornersOnce, real sfx.

import type { PrivateMessage, TopicMessage } from '../online/messages';
import type { GameSocket, GameSocketHandlers } from '../online/socket';

export interface TutorialSocketHooks {
  onPublish: (action: string, body: unknown) => void;
  /** Fired straight after the store's onConnect, so the driver can open the match. */
  onConnected: () => void;
}

export class TutorialSocket implements GameSocket {
  private handlers: GameSocketHandlers | null = null;
  private readonly hooks: TutorialSocketHooks;
  private stopped = false;

  constructor(hooks: TutorialSocketHooks) {
    this.hooks = hooks;
  }

  activate(_token: string, handlers: GameSocketHandlers): void {
    this.handlers = handlers;
    // Re-armable on purpose: StrictMode mounts, tears down, then mounts again with the
    // same instance, so deactivate() must not permanently kill the socket.
    this.stopped = false;
    // Async so the caller's set({ conn: 'connecting' }) commits first — mirrors a real
    // socket, where onConnect can never land synchronously inside activate().
    queueMicrotask(() => {
      if (this.stopped) return;
      handlers.onConnect();
      this.hooks.onConnected();
    });
  }

  subscribeMatch(): void {}

  unsubscribeMatch(): void {}

  publish(destination: string, body: unknown): void {
    if (this.stopped) return;
    // Destinations look like `/app/match.{id}.{action}` or `/app/queue.{action}`.
    this.hooks.onPublish(destination.slice(destination.lastIndexOf('.') + 1), body);
  }

  deactivate(): void {
    this.stopped = true;
    this.handlers = null;
  }

  emitPrivate(msg: PrivateMessage): void {
    if (!this.stopped) this.handlers?.onPrivateMessage(msg);
  }

  emitTopic(msg: TopicMessage): void {
    if (!this.stopped) this.handlers?.onMatchMessage(msg);
  }
}
