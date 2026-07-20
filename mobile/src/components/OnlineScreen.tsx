import { useEffect, useState } from 'react';
import { StyleSheet, Text, TextInput, View } from 'react-native';
import { loadIdentity } from '../online/api';
import { useOnlineStore } from '../online/onlineStore';
import { colors, spacing } from '../theme';
import { Match } from './Match';
import { Banner, Button, Panel, Spinner } from './ui';

export function OnlineScreen() {
  const stage = useOnlineStore((s) => s.stage);
  const conn = useOnlineStore((s) => s.conn);
  const error = useOnlineStore((s) => s.error);
  const dismissError = useOnlineStore((s) => s.dismissError);
  const leave = useOnlineStore((s) => s.leave);

  return (
    <View style={styles.screen}>
      {stage !== 'match' && <Text style={styles.title}>Regroup</Text>}

      {conn === 'reconnecting' && (
        <Banner kind="warn">
          <View style={styles.bannerRow}>
            <Spinner />
            <Text style={styles.bannerText}> Connection lost — reconnecting…</Text>
          </View>
        </Banner>
      )}
      {error && (
        <Banner kind="error" onDismiss={dismissError}>
          <Text style={styles.bannerText}>{error.message || error.code}</Text>
        </Banner>
      )}

      {stage === 'name' && <NameEntry />}
      {stage === 'lobby' && <Lobby />}
      {stage === 'queue' && <QueueScreen />}
      {stage === 'match' && <Match onExit={leave} />}
    </View>
  );
}

function NameEntry() {
  const [name, setName] = useState('');
  const conn = useOnlineStore((s) => s.conn);
  const start = useOnlineStore((s) => s.start);
  const connecting = conn === 'connecting';

  // Prefill the last used name from AsyncStorage (async, unlike the web's
  // synchronous localStorage read).
  useEffect(() => {
    void loadIdentity().then((identity) => {
      if (identity?.name) setName((n) => n || identity.name);
    });
  }, []);

  return (
    <View style={styles.center}>
      <Panel style={styles.panel}>
        <Text style={styles.heading}>Play online</Text>
        <Text style={styles.subtitle}>Pick a name to enter matchmaking. 4 players per match.</Text>
        <TextInput
          style={styles.input}
          value={name}
          maxLength={24}
          placeholder="Your name"
          placeholderTextColor={colors.textDim}
          editable={!connecting}
          onChangeText={setName}
          onSubmitEditing={() => void start(name)}
          returnKeyType="go"
        />
        <Button
          label={connecting ? 'Connecting…' : 'Connect'}
          kind="primary"
          big
          disabled={connecting || !name.trim()}
          onPress={() => void start(name)}
        />
        {connecting && <Spinner />}
      </Panel>
    </View>
  );
}

function Lobby() {
  const name = useOnlineStore((s) => s.identity?.name);
  const joinQueue = useOnlineStore((s) => s.joinQueue);
  const playOffline = useOnlineStore((s) => s.playOffline);
  const leave = useOnlineStore((s) => s.leave);
  return (
    <View style={styles.center}>
      <Panel style={styles.panel}>
        <Text style={styles.heading}>Connected as {name}</Text>
        <Button label="Find a match" kind="primary" big onPress={joinQueue} />
        <Button label="Play offline vs bots" kind="primary" big onPress={playOffline} />
        <Button label="Sign out" kind="ghost" onPress={leave} />
      </Panel>
    </View>
  );
}

function QueueScreen() {
  const leaveQueue = useOnlineStore((s) => s.leaveQueue);
  return (
    <View style={styles.center}>
      <Panel style={styles.panel}>
        <Text style={styles.heading}>Searching for players…</Text>
        <Spinner />
        <Text style={styles.subtitle}>Waiting for 4 players to be matched.</Text>
        <Button label="Leave queue" onPress={leaveQueue} />
      </Panel>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: colors.bg,
  },
  title: {
    color: colors.text,
    fontSize: 30,
    fontWeight: '900',
    textAlign: 'center',
    marginTop: spacing.lg,
    letterSpacing: 1,
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    padding: spacing.lg,
  },
  panel: {
    gap: spacing.md,
    alignItems: 'stretch',
  },
  heading: {
    color: colors.text,
    fontSize: 20,
    fontWeight: '700',
    textAlign: 'center',
  },
  subtitle: {
    color: colors.textDim,
    textAlign: 'center',
  },
  input: {
    backgroundColor: colors.panelSoft,
    borderColor: colors.border,
    borderWidth: 1,
    borderRadius: 8,
    color: colors.text,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    fontSize: 16,
  },
  bannerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  bannerText: {
    color: colors.text,
  },
});
