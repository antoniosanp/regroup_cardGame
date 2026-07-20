// Hosts the guided tutorial. It owns a private online store wired to the scripted socket and
// provides it through OnlineStoreContext, so the real <Match> and every one of its children
// render verbatim — the tutorial cannot drift from the live game because it *is* the live UI.

import { useEffect, useState, useSyncExternalStore } from 'react';
import { createOnlineStore, OnlineStoreContext, useOnlineStore } from '../online/onlineStore';
import { Match } from '../components/online/Match';
import { TutorialDriver } from './TutorialDriver';
import { TutorialOverlay } from './TutorialOverlay';
import { TUTORIAL_IDENTITY } from './tutorialScript';

/**
 * Lives inside the provider so it reads the tutorial's store, not the app singleton. The
 * overlay's selectors point at DOM that the store remounts (the held card appears, the board
 * regrows), so it needs a signal to re-apply its highlight classes.
 */
function TutorialBody({ onExit, driver }: { onExit: () => void; driver: TutorialDriver }) {
  const view = useSyncExternalStore(driver.subscribe, driver.getView);
  const boardSize = useOnlineStore((s) => Object.values(s.boards).flat().length);
  const holding = useOnlineStore((s) => s.heldCard !== null);
  const phase = useOnlineStore((s) => s.phase);

  return (
    <>
      <Match onExit={onExit} pauseTimer />
      <TutorialOverlay
        view={view}
        domRevision={`${boardSize}:${holding}:${phase}`}
        onNext={() => driver.next()}
        onExit={onExit}
      />
    </>
  );
}

export function TutorialScreen({ onExit }: { onExit: () => void }) {
  // One store + driver per mount, built lazily so StrictMode's double-invoked render does
  // not create two sockets.
  const [{ store, driver }] = useState(() => {
    const tutorialDriver = new TutorialDriver();
    return { store: createOnlineStore(() => tutorialDriver.socket), driver: tutorialDriver };
  });

  useEffect(() => {
    store.getState().startWithIdentity(TUTORIAL_IDENTITY);
    return () => {
      // Both are re-armable: StrictMode tears down and remounts with these same instances,
      // and leave() resets the store so the replay starts cleanly from step 1.
      driver.stop();
      store.getState().leave();
    };
  }, [store, driver]);

  return (
    <OnlineStoreContext.Provider value={store}>
      <TutorialBody onExit={onExit} driver={driver} />
    </OnlineStoreContext.Provider>
  );
}
