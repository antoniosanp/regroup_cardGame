// Small shared UI primitives: buttons, panels, banners.

import type { ReactNode } from 'react';
import {
  ActivityIndicator,
  Pressable,
  StyleSheet,
  Text,
  View,
  type StyleProp,
  type ViewStyle,
} from 'react-native';
import { colors, spacing } from '../theme';

interface ButtonProps {
  label: string;
  onPress: () => void;
  disabled?: boolean;
  kind?: 'primary' | 'plain' | 'ghost';
  big?: boolean;
  style?: StyleProp<ViewStyle>;
}

export function Button({ label, onPress, disabled, kind = 'plain', big, style }: ButtonProps) {
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled}
      style={({ pressed }) => [
        styles.btn,
        kind === 'primary' && styles.btnPrimary,
        kind === 'ghost' && styles.btnGhost,
        big && styles.btnBig,
        disabled && styles.btnDisabled,
        pressed && !disabled && styles.btnPressed,
        style,
      ]}
    >
      <Text
        style={[
          styles.btnText,
          kind === 'primary' && styles.btnTextPrimary,
          kind === 'ghost' && styles.btnTextGhost,
          big && styles.btnTextBig,
          disabled && styles.btnTextDisabled,
        ]}
      >
        {label}
      </Text>
    </Pressable>
  );
}

export function Panel({ children, style }: { children: ReactNode; style?: StyleProp<ViewStyle> }) {
  return <View style={[styles.panel, style]}>{children}</View>;
}

export function Banner({
  kind,
  children,
  onDismiss,
}: {
  kind: 'warn' | 'error';
  children: ReactNode;
  onDismiss?: () => void;
}) {
  return (
    <View style={[styles.banner, kind === 'warn' ? styles.bannerWarn : styles.bannerError]}>
      <View style={styles.bannerBody}>{children}</View>
      {onDismiss && (
        <Pressable onPress={onDismiss} hitSlop={8}>
          <Text style={styles.bannerDismiss}>Dismiss</Text>
        </Pressable>
      )}
    </View>
  );
}

export function Spinner() {
  return <ActivityIndicator color={colors.primary} />;
}

const styles = StyleSheet.create({
  btn: {
    backgroundColor: colors.panelSoft,
    borderColor: colors.border,
    borderWidth: 1,
    borderRadius: 8,
    paddingVertical: spacing.sm,
    paddingHorizontal: spacing.lg,
    alignItems: 'center',
  },
  btnPrimary: {
    backgroundColor: colors.primary,
    borderColor: colors.primaryDark,
  },
  btnGhost: {
    backgroundColor: 'transparent',
    borderColor: 'transparent',
  },
  btnBig: {
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.xl,
    minWidth: 220,
  },
  btnDisabled: {
    opacity: 0.45,
  },
  btnPressed: {
    opacity: 0.75,
  },
  btnText: {
    color: colors.text,
    fontWeight: '600',
  },
  btnTextPrimary: {
    color: '#fff',
  },
  btnTextGhost: {
    color: colors.textDim,
  },
  btnTextBig: {
    fontSize: 17,
  },
  btnTextDisabled: {
    color: colors.textDim,
  },
  panel: {
    backgroundColor: colors.panel,
    borderColor: colors.border,
    borderWidth: 1,
    borderRadius: 12,
    padding: spacing.lg,
  },
  banner: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: 8,
    padding: spacing.md,
    marginBottom: spacing.sm,
    gap: spacing.sm,
  },
  bannerWarn: {
    backgroundColor: '#3a2f16',
    borderColor: colors.warn,
    borderWidth: 1,
  },
  bannerError: {
    backgroundColor: '#3a1a1a',
    borderColor: colors.danger,
    borderWidth: 1,
  },
  bannerBody: {
    flex: 1,
  },
  bannerDismiss: {
    color: colors.textDim,
    fontWeight: '600',
  },
});
