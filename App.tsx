import React, { useCallback, useEffect, useState } from "react";
import {
  ActivityIndicator,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  View,
  useWindowDimensions,
} from "react-native";
import { StatusBar } from "expo-status-bar";
import { fetchGauge, scoreColor, GraphData } from "./src/api";
import GaugeDial from "./src/GaugeDial";
import Sparkline from "./src/Sparkline";

export default function App() {
  const [data, setData] = useState<GraphData | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const { width } = useWindowDimensions();

  const load = useCallback(async () => {
    try {
      setError(null);
      setData(await fetchGauge());
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load");
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await load();
    setRefreshing(false);
  }, [load]);

  const fg = data?.fear_and_greed;
  const history = data?.fear_and_greed_historical.data ?? [];
  const spark = history.slice(-30).map((p) => p.y);

  return (
    <View style={styles.container}>
      <StatusBar style="light" />
      <ScrollView
        contentContainerStyle={styles.content}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#b0b0b8" />
        }
      >
        <Text style={styles.title}>Fear & Greed Index</Text>

        {!data && !error && <ActivityIndicator size="large" color="#b0b0b8" style={styles.loader} />}

        {error && (
          <View style={styles.errorBox}>
            <Text style={styles.errorText}>{error}</Text>
            <Text style={styles.errorHint}>Pull down to retry</Text>
          </View>
        )}

        {fg && (
          <>
            <GaugeDial score={fg.score} rating={fg.rating} />
            <Text style={styles.updated}>
              Updated {new Date(fg.timestamp).toLocaleString()}
            </Text>

            {spark.length > 1 && (
              <View style={styles.section}>
                <Text style={styles.sectionTitle}>Last 30 days</Text>
                <Sparkline data={spark} color={scoreColor(fg.score)} width={width - 48} />
              </View>
            )}

            <View style={styles.section}>
              <HistoryRow label="Previous close" value={fg.previous_close} />
              <HistoryRow label="1 week ago" value={fg.previous_1_week} />
              <HistoryRow label="1 month ago" value={fg.previous_1_month} />
              <HistoryRow label="1 year ago" value={fg.previous_1_year} />
            </View>
          </>
        )}
      </ScrollView>
    </View>
  );
}

function HistoryRow({ label, value }: { label: string; value: number }) {
  return (
    <View style={styles.row}>
      <Text style={styles.rowLabel}>{label}</Text>
      <Text style={[styles.rowValue, { color: scoreColor(value) }]}>{Math.round(value)}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#131316",
  },
  content: {
    alignItems: "center",
    paddingTop: 84,
    paddingBottom: 48,
    paddingHorizontal: 24,
  },
  title: {
    color: "#f0f0f2",
    fontSize: 24,
    fontWeight: "700",
    marginBottom: 32,
  },
  loader: {
    marginTop: 64,
  },
  errorBox: {
    marginTop: 64,
    alignItems: "center",
  },
  errorText: {
    color: "#ff6b6b",
    fontSize: 16,
    textAlign: "center",
  },
  errorHint: {
    color: "#808088",
    marginTop: 8,
  },
  updated: {
    color: "#808088",
    fontSize: 13,
    marginTop: 36,
  },
  section: {
    width: "100%",
    marginTop: 32,
  },
  sectionTitle: {
    color: "#b0b0b8",
    fontSize: 14,
    fontWeight: "600",
    marginBottom: 12,
  },
  row: {
    flexDirection: "row",
    justifyContent: "space-between",
    paddingVertical: 10,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: "#2a2a2e",
  },
  rowLabel: {
    color: "#d0d0d4",
    fontSize: 15,
  },
  rowValue: {
    fontSize: 15,
    fontWeight: "700",
    fontVariant: ["tabular-nums"],
  },
});
