import React, { useState, useEffect, useMemo } from 'react';
import axios from 'axios';
import { API_BASE_URL } from '../../config/api';

// ── Types ─────────────────────────────────────────────────────────────────────

interface CatchRow {
  id: number;
  fishSpecies: string;
  quantityKg: number;
  weightDiscrepancyPct: number;
  status: string;
  fraudRisk: string;
  qualityScore: number;
  validationSummary: string;
  requiresAdminReview: boolean;
}

interface WorkflowRow {
  id: number;
  workflowId: string;
  catchId: number;
  currentAgent: string;
  status: string;
  recommendationSummary: string;
  lastUpdatedAt: string;
}

// ── Colours ───────────────────────────────────────────────────────────────────

const C = {
  low: '#10b981',
  medium: '#f59e0b',
  high: '#ef4444',
  none: '#94a3b8',
  blue: '#0ea5e9',
  navy: '#005b96',
  purple: '#8b5cf6',
  text: '#0f172a',
  muted: '#64748b',
  border: '#e2e8f0',
};

const statusColor = (s: string): string => {
  if (s === 'Approved' || s === 'Completed') return C.low;
  if (s === 'PendingApproval') return C.medium;
  if (s === 'Rejected' || s === 'Failed') return C.high;
  return C.blue;
};

const cardStyle: React.CSSProperties = {
  background: 'white',
  border: `1px solid ${C.border}`,
  borderRadius: 12,
  padding: 18,
  boxShadow: '0 1px 3px rgba(15,23,42,0.06)',
};

const titleStyle: React.CSSProperties = {
  margin: '0 0 12px 0',
  fontSize: '0.9rem',
  fontWeight: 700,
  color: C.text,
};

// ── Small chart pieces ────────────────────────────────────────────────────────

const Kpi: React.FC<{ label: string; value: string; sub?: string; color: string }> = ({
  label, value, sub, color,
}) => (
  <div style={{ ...cardStyle, borderTop: `4px solid ${color}` }}>
    <div style={{ fontSize: '0.72rem', color: C.muted, fontWeight: 600, textTransform: 'uppercase' }}>
      {label}
    </div>
    <div style={{ fontSize: '1.8rem', fontWeight: 800, color: C.text, marginTop: 4 }}>{value}</div>
    {sub && <div style={{ fontSize: '0.75rem', color: C.muted, marginTop: 2 }}>{sub}</div>}
  </div>
);

const Donut: React.FC<{ parts: { label: string; value: number; color: string }[] }> = ({ parts }) => {
  const total = parts.reduce((sum, p) => sum + p.value, 0);
  const radius = 54;
  const circ = 2 * Math.PI * radius;
  let offset = 0;

  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 20, flexWrap: 'wrap' }}>
      <svg width={150} height={150} viewBox="0 0 150 150">
        <circle cx={75} cy={75} r={radius} fill="none" stroke="#f1f5f9" strokeWidth={22} />
        {total > 0 &&
          parts.map((p) => {
            const len = (p.value / total) * circ;
            const el = (
              <circle
                key={p.label}
                cx={75}
                cy={75}
                r={radius}
                fill="none"
                stroke={p.color}
                strokeWidth={22}
                strokeDasharray={`${len} ${circ - len}`}
                strokeDashoffset={-offset}
                transform="rotate(-90 75 75)"
              />
            );
            offset += len;
            return el;
          })}
        <text x={75} y={72} textAnchor="middle" fontSize={26} fontWeight={800} fill={C.text}>
          {total}
        </text>
        <text x={75} y={90} textAnchor="middle" fontSize={11} fill={C.muted}>
          catches
        </text>
      </svg>
      <div style={{ display: 'grid', gap: 6 }}>
        {parts.map((p) => (
          <div key={p.label} style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: '0.8rem' }}>
            <span style={{ width: 10, height: 10, borderRadius: 3, background: p.color }} />
            <span style={{ color: C.text, fontWeight: 600 }}>{p.label}</span>
            <span style={{ color: C.muted }}>{p.value}</span>
          </div>
        ))}
      </div>
    </div>
  );
};

const HBars: React.FC<{
  rows: { label: string; value: number; color: string }[];
  max?: number;
  suffix?: string;
}> = ({ rows, max, suffix = '' }) => {
  const top = max ?? Math.max(1, ...rows.map((r) => r.value));
  return (
    <div style={{ display: 'grid', gap: 10 }}>
      {rows.map((r) => (
        <div key={r.label}>
          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.78rem', marginBottom: 3 }}>
            <span style={{ color: C.text, fontWeight: 600 }}>{r.label}</span>
            <span style={{ color: C.muted }}>
              {r.value}
              {suffix}
            </span>
          </div>
          <div style={{ height: 10, background: '#f1f5f9', borderRadius: 6, overflow: 'hidden' }}>
            <div
              style={{
                width: `${Math.min(100, (r.value / top) * 100)}%`,
                height: '100%',
                background: r.color,
                borderRadius: 6,
                transition: 'width 0.6s ease',
              }}
            />
          </div>
        </div>
      ))}
    </div>
  );
};

// Weight discrepancy per catch, with the 10% warning and 25% fraud lines
const DiscrepancyChart: React.FC<{ rows: CatchRow[] }> = ({ rows }) => {
  const data = rows.slice(0, 14);
  const W = 560;
  const H = 220;
  const padL = 36;
  const padB = 28;
  const padT = 10;
  const maxVal = Math.max(30, ...data.map((d) => d.weightDiscrepancyPct));
  const plotH = H - padB - padT;
  const plotW = W - padL - 10;
  const slot = data.length > 0 ? plotW / data.length : plotW;
  const barW = Math.min(28, slot * 0.6);
  const y = (v: number) => padT + plotH - (v / maxVal) * plotH;

  return (
    <div style={{ overflowX: 'auto' }}>
      <svg viewBox={`0 0 ${W} ${H}`} width="100%" style={{ minWidth: 380 }}>
        {[0, 10, 25].map((t) => (
          <g key={t}>
            <line
              x1={padL}
              x2={W - 10}
              y1={y(t)}
              y2={y(t)}
              stroke={t === 25 ? C.high : t === 10 ? C.medium : C.border}
              strokeDasharray={t === 0 ? undefined : '5 4'}
              strokeWidth={1}
            />
            <text x={padL - 6} y={y(t) + 4} textAnchor="end" fontSize={10} fill={C.muted}>
              {t}%
            </text>
          </g>
        ))}
        {data.map((d, i) => {
          const x = padL + i * slot + (slot - barW) / 2;
          const v = d.weightDiscrepancyPct;
          const color = v > 25 ? C.high : v > 10 ? C.medium : C.low;
          return (
            <g key={d.id}>
              <rect x={x} y={y(v)} width={barW} height={Math.max(2, padT + plotH - y(v))} rx={4} fill={color} />
              <text x={x + barW / 2} y={H - 10} textAnchor="middle" fontSize={10} fill={C.muted}>
                #{d.id}
              </text>
            </g>
          );
        })}
      </svg>
      <div style={{ display: 'flex', gap: 14, fontSize: '0.72rem', color: C.muted, flexWrap: 'wrap' }}>
        <span><b style={{ color: C.low }}>■</b> ≤10% OK</span>
        <span><b style={{ color: C.medium }}>■</b> 10–25% warning</span>
        <span><b style={{ color: C.high }}>■</b> &gt;25% fraud risk</span>
      </div>
    </div>
  );
};

// ── Main component ────────────────────────────────────────────────────────────

export const AIWorkflowAnalytics: React.FC = () => {
  const [catches, setCatches] = useState<CatchRow[]>([]);
  const [workflows, setWorkflows] = useState<WorkflowRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let cancelled = false;
    const headers = { Authorization: `Bearer ${localStorage.getItem('token')}` };

    const load = async () => {
      setLoading(true);
      setError('');
      try {
        const [cRes, wRes] = await Promise.allSettled([
          axios.get(`${API_BASE_URL}/api/Catches?pageSize=100`, { headers }),
          axios.get(`${API_BASE_URL}/api/AgentGateway/workflows`, { headers }),
        ]);

        if (cancelled) return;

        if (cRes.status === 'fulfilled') {
          const raw = cRes.value.data;
          const list: CatchRow[] = Array.isArray(raw) ? raw : raw?.items ?? [];
          setCatches(list);
        } else {
          setError('Could not load catches from the API.');
        }

        if (wRes.status === 'fulfilled') {
          setWorkflows(Array.isArray(wRes.value.data) ? wRes.value.data : []);
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    };

    load();
    return () => {
      cancelled = true;
    };
  }, []);

  const stats = useMemo(() => {
    const assessed = catches.filter((c) => c.fraudRisk && c.fraudRisk !== 'Unassessed');
    const count = (r: string) => catches.filter((c) => c.fraudRisk === r).length;
    const low = count('Low');
    const medium = count('Medium');
    const high = count('High');
    const unassessed = catches.length - low - medium - high;

    const scored = catches.filter((c) => c.qualityScore > 0);
    const avgScore = scored.length
      ? scored.reduce((s, c) => s + c.qualityScore, 0) / scored.length
      : 0;

    const withDisc = catches.filter((c) => c.weightDiscrepancyPct > 0);
    const avgDisc = withDisc.length
      ? withDisc.reduce((s, c) => s + c.weightDiscrepancyPct, 0) / withDisc.length
      : 0;

    const pending = catches.filter((c) => c.requiresAdminReview).length;

    // Average quality score by species
    const bySpecies: Record<string, { sum: number; n: number }> = {};
    scored.forEach((c) => {
      const k = c.fishSpecies || 'Unknown';
      if (!bySpecies[k]) bySpecies[k] = { sum: 0, n: 0 };
      bySpecies[k].sum += c.qualityScore;
      bySpecies[k].n += 1;
    });
    const speciesRows = Object.keys(bySpecies)
      .map((k) => ({
        label: k,
        value: Math.round(bySpecies[k].sum / bySpecies[k].n),
        color: C.navy,
      }))
      .sort((a, b) => b.value - a.value)
      .slice(0, 6);

    return { assessed: assessed.length, low, medium, high, unassessed, avgScore, avgDisc, pending, speciesRows };
  }, [catches]);

  const agentRows = useMemo(() => {
    const tally: Record<string, number> = {};
    workflows.forEach((w) => {
      const k = w.currentAgent || 'Unknown';
      tally[k] = (tally[k] ?? 0) + 1;
    });
    return Object.keys(tally).map((k) => ({ label: k, value: tally[k], color: C.purple }));
  }, [workflows]);

  const statusRows = useMemo(() => {
    const tally: Record<string, number> = {};
    workflows.forEach((w) => {
      tally[w.status] = (tally[w.status] ?? 0) + 1;
    });
    return Object.keys(tally).map((k) => ({ label: k, value: tally[k], color: statusColor(k) }));
  }, [workflows]);

  const discrepancyRows = useMemo(
    () => catches.filter((c) => c.weightDiscrepancyPct > 0 || c.fraudRisk === 'High'),
    [catches]
  );

  if (loading) {
    return <div style={{ ...cardStyle, textAlign: 'center', color: C.muted }}>Loading AI analysis…</div>;
  }

  return (
    <div style={{ display: 'grid', gap: 18, marginBottom: 24 }}>
      {error && (
        <div style={{ ...cardStyle, borderLeft: `4px solid ${C.high}`, color: '#991b1b' }}>{error}</div>
      )}

      {/* KPI row */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(170px, 1fr))', gap: 14 }}>
        <Kpi label="Catches analysed" value={String(stats.assessed)} sub={`of ${catches.length} total`} color={C.blue} />
        <Kpi label="Avg quality score" value={stats.avgScore ? stats.avgScore.toFixed(0) : '–'} sub="out of 100" color={C.low} />
        <Kpi label="High risk flags" value={String(stats.high)} sub="weight discrepancy > 25%" color={C.high} />
        <Kpi label="Awaiting admin" value={String(stats.pending)} sub="human approval needed" color={C.medium} />
        <Kpi label="Avg discrepancy" value={stats.avgDisc ? `${stats.avgDisc.toFixed(1)}%` : '–'} sub="declared vs scale" color={C.purple} />
      </div>

      {/* Risk donut + species quality */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: 14 }}>
        <div style={cardStyle}>
          <h4 style={titleStyle}>Fraud risk distribution</h4>
          <Donut
            parts={[
              { label: 'Low', value: stats.low, color: C.low },
              { label: 'Medium', value: stats.medium, color: C.medium },
              { label: 'High', value: stats.high, color: C.high },
              { label: 'Unassessed', value: stats.unassessed, color: C.none },
            ]}
          />
        </div>
        <div style={cardStyle}>
          <h4 style={titleStyle}>Average quality score by species</h4>
          {stats.speciesRows.length === 0 ? (
            <div style={{ color: C.muted, fontSize: '0.85rem' }}>No scored catches yet.</div>
          ) : (
            <HBars rows={stats.speciesRows} max={100} />
          )}
        </div>
      </div>

      {/* Discrepancy chart */}
      <div style={cardStyle}>
        <h4 style={titleStyle}>Weight discrepancy per catch (declared vs pier scale)</h4>
        {discrepancyRows.length === 0 ? (
          <div style={{ color: C.muted, fontSize: '0.85rem' }}>No weight discrepancies recorded yet.</div>
        ) : (
          <DiscrepancyChart rows={discrepancyRows} />
        )}
      </div>

      {/* Agent pipeline */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: 14 }}>
        <div style={cardStyle}>
          <h4 style={titleStyle}>Workflows by agent</h4>
          {agentRows.length === 0 ? (
            <div style={{ color: C.muted, fontSize: '0.85rem' }}>No agent workflows recorded yet.</div>
          ) : (
            <HBars rows={agentRows} />
          )}
        </div>
        <div style={cardStyle}>
          <h4 style={titleStyle}>Workflows by status</h4>
          {statusRows.length === 0 ? (
            <div style={{ color: C.muted, fontSize: '0.85rem' }}>No workflow statuses yet.</div>
          ) : (
            <HBars rows={statusRows} />
          )}
        </div>
      </div>

      {/* Timeline */}
      <div style={cardStyle}>
        <h4 style={titleStyle}>Recent agent activity</h4>
        {workflows.length === 0 ? (
          <div style={{ color: C.muted, fontSize: '0.85rem' }}>
            No activity yet. Submit a catch with the AI agent running to see steps appear here.
          </div>
        ) : (
          <div style={{ display: 'grid', gap: 12 }}>
            {workflows.slice(0, 8).map((w) => (
              <div key={w.id} style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
                <span
                  style={{
                    width: 12,
                    height: 12,
                    borderRadius: '50%',
                    background: statusColor(w.status),
                    marginTop: 4,
                    flexShrink: 0,
                  }}
                />
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: '0.82rem', fontWeight: 700, color: C.text }}>
                    {w.currentAgent || 'Agent'} · Catch #{w.catchId} · {w.status}
                  </div>
                  <div style={{ fontSize: '0.78rem', color: C.muted }}>{w.recommendationSummary}</div>
                  <div style={{ fontSize: '0.7rem', color: '#94a3b8' }}>
                    {new Date(w.lastUpdatedAt).toLocaleString()}
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};