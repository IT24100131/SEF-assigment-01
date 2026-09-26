import React, { useState, useEffect } from 'react';
import {
  CheckCircle, XCircle, RefreshCw,
  ShieldCheck, Eye, ChevronDown, ChevronUp,
  Activity, Fish, Scale, Star, Clock, Truck, MapPin,
} from 'lucide-react';
import axios from 'axios';
import { API_BASE_URL } from '../../config/api';

// ── Types ─────────────────────────────────────────────────────────────────────

interface DeliveryPlan {
  id: number;
  planId: string;
  catchId: number;
  vehicleCode: string;
  driverCode: string;
  coldStorageCode: string;
  pickupLocation: string;
  deliveryLocation: string;
  selectedRoute: string;
  distanceKm: number;
  estimatedMinutes: number;
  pickupTime: string | null;
  estimatedETA: string | null;
  status: string;
  agentReasoning: string;
  weatherNote: string;
  adminNote: string;
  createdAt: string;
}

// ── Types ─────────────────────────────────────────────────────────────────────

interface FlaggedCatch {
  id: number;
  fishSpecies: string;
  quantityKg: number;
  verifiedWeightKg: number;
  weightDiscrepancyPct: number;
  askingPricePerKg: number;
  location: string;
  status: string;
  declaredQualityGrade: string;
  inspectionResult: string;
  fraudRisk: string;
  qualityScore: number;
  validationSummary: string;
  requiresAdminReview: boolean;
  sellerNote: string;
  catchDateTime: string | null;
  createdAt: string;
  fisherman?: { fullName: string; email: string };
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const riskColor = (r: string) =>
  r === 'High' ? '#991b1b' : r === 'Medium' ? '#92400e' : r === 'Low' ? '#065f46' : '#475569';
const riskBg = (r: string) =>
  r === 'High' ? '#fee2e2' : r === 'Medium' ? '#fef3c7' : r === 'Low' ? '#d1fae5' : '#f1f5f9';
const riskBorder = (r: string) =>
  r === 'High' ? '#fca5a5' : r === 'Medium' ? '#fde68a' : r === 'Low' ? '#6ee7b7' : '#e2e8f0';
const riskIcon = (r: string) =>
  r === 'High' ? '🚨' : r === 'Medium' ? '⚠️' : r === 'Low' ? '✅' : '❓';

// ── Weather Widget (OpenWeatherMap via ASP.NET Core) ─────────────────────────

const WeatherWidget: React.FC = () => {
  const [weather, setWeather] = useState<any[]>([]);
  const [wLoading, setWLoading] = useState(true);
  const authHeader = { Authorization: `Bearer ${localStorage.getItem('token')}` };

  useEffect(() => {
    axios.get(`${API_BASE_URL}/api/Weather/locations`, { headers: authHeader })
      .then(r => setWeather(r.data))
      .catch(() => {})
      .finally(() => setWLoading(false));
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const riskColor = (r: string) =>
    r === 'High' ? '#ef4444' : r === 'Moderate' ? '#f59e0b' : '#10b981';

  if (wLoading) return null;
  if (!weather.length) return null;

  return (
    <div style={{ marginBottom: 24 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12 }}>
        <span style={{ fontSize: '1.1rem' }}>🌤️</span>
        <h3 style={{ margin: 0, fontSize: '0.95rem', color: '#334155' }}>
          Live Weather — Sri Lanka Fishing Ports
          <span style={{ fontWeight: 400, color: '#94a3b8', fontSize: '0.78rem', marginLeft: 8 }}>
            via OpenWeatherMap
          </span>
        </h3>
      </div>
      <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
        {weather.map((w: any) => (
          <div key={w.location} style={{
            background: 'white', borderRadius: 10, padding: '12px 16px',
            boxShadow: '0 2px 8px rgba(0,0,0,0.07)', minWidth: 140, flex: '1',
            borderTop: `3px solid ${riskColor(w.fishingRisk)}`,
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
              {w.iconUrl && <img src={w.iconUrl} alt={w.condition} width={28} height={28} />}
              <span style={{ fontWeight: 700, fontSize: '0.85rem', color: '#1e293b' }}>
                {w.location}
              </span>
            </div>
            <p style={{ margin: '2px 0', fontSize: '0.78rem', color: '#475569' }}>
              {w.condition} · {w.tempCelsius}°C
            </p>
            <p style={{ margin: '2px 0', fontSize: '0.78rem', color: '#64748b' }}>
              Wind: {w.windSpeedKmh} km/h
            </p>
            <span style={{ display: 'inline-block', marginTop: 4, padding: '1px 8px',
              borderRadius: 8, fontSize: '0.72rem', fontWeight: 700,
              background: riskColor(w.fishingRisk) + '20',
              color: riskColor(w.fishingRisk) }}>
              Fishing: {w.fishingRisk} risk
            </span>
          </div>
        ))}
      </div>
    </div>
  );
};

// ── Admin Dashboard ───────────────────────────────────────────────────────────

export const AdminDashboard: React.FC<{
  defaultTab?: 'flagged' | 'workflows' | 'logistics' | 'marketplace';
  onTabChange?: (tab: string) => void;
}> = ({ defaultTab = 'flagged' }) => {
  const [activeTab,     setActiveTab]     = useState<'flagged' | 'workflows' | 'logistics' | 'marketplace'>(defaultTab);

  // Sync when parent sidebar tab changes
  useEffect(() => { setActiveTab(defaultTab as any); }, [defaultTab]);
  const [flagged,       setFlagged]       = useState<FlaggedCatch[]>([]);
  const [published,     setPublished]     = useState<FlaggedCatch[]>([]);
  const [workflows,     setWorkflows]     = useState<any[]>([]);
  const [deliveryPlans, setDeliveryPlans] = useState<DeliveryPlan[]>([]);
  const [loading,       setLoading]       = useState(false);
  const [actionMsg,     setActionMsg]     = useState('');
  const [expanded,      setExpanded]      = useState<number | null>(null);

  const authHeader = { Authorization: `Bearer ${localStorage.getItem('token')}` };

  const fetchFlagged = async () => {
    setLoading(true);
    try {
      const res = await axios.get<FlaggedCatch[]>(
        `${API_BASE_URL}/api/Catches/flagged`, { headers: authHeader }
      );
      setFlagged(res.data);
    } catch { setFlagged([]); }
    finally { setLoading(false); }
  };

  const fetchPublished = async () => {
    setLoading(true);
    try {
      const res = await axios.get(
        `${API_BASE_URL}/api/Catches?status=Published`, { headers: authHeader }
      );
      setPublished(res.data.items ?? res.data);
    } catch { setPublished([]); }
    finally { setLoading(false); }
  };

  const fetchWorkflows = async () => {
    setLoading(true);
    try {
      // AgentWorkflows doesn't have a list endpoint yet — fetch all catches and
      // use their validation summaries as a proxy
      const res = await axios.get<FlaggedCatch[]>(
        `${API_BASE_URL}/api/Catches`, { headers: authHeader }
      );
      // Show all catches that have a validation summary
      const withSummary = res.data.filter((c: any) => c.validationSummary);
      setWorkflows(withSummary as any);
    } catch { setWorkflows([]); }
    finally { setLoading(false); }
  };

  const fetchDeliveryPlans = async () => {
    try {
      const res = await axios.get<DeliveryPlan[]>(
        `${API_BASE_URL}/api/Logistics/plans`, { headers: authHeader }
      );
      setDeliveryPlans(res.data);
    } catch { setDeliveryPlans([]); }
  };

  const handleApprovePlan = async (id: number) => {
    try {
      await axios.patch(`${API_BASE_URL}/api/Logistics/plans/${id}/approve`, {}, { headers: authHeader });
      setActionMsg(`✅ Delivery plan #${id} approved and scheduled.`);
      await fetchDeliveryPlans();
      setTimeout(() => setActionMsg(''), 4000);
    } catch (err: any) {
      setActionMsg(`❌ Error: ${err.response?.data ?? 'Approval failed.'}`);
    }
  };

  const handleRejectPlan = async (id: number) => {
    if (!window.confirm(`Reject delivery plan #${id}?`)) return;
    try {
      await axios.patch(`${API_BASE_URL}/api/Logistics/plans/${id}/reject`, {}, { headers: authHeader });
      setActionMsg(`🚫 Delivery plan #${id} rejected.`);
      await fetchDeliveryPlans();
      setTimeout(() => setActionMsg(''), 4000);
    } catch (err: any) {
      setActionMsg(`❌ Error: ${err.response?.data ?? 'Rejection failed.'}`);
    }
  };

  const handleCompletePlan = async (id: number) => {
    try {
      await axios.patch(`${API_BASE_URL}/api/Logistics/plans/${id}/complete`, {}, { headers: authHeader });
      setActionMsg(`🏁 Delivery #${id} marked as delivered.`);
      await fetchDeliveryPlans();
      setTimeout(() => setActionMsg(''), 4000);
    } catch (err: any) {
      setActionMsg(`❌ Error: ${err.response?.data ?? 'Failed.'}`);
    }
  };

  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { fetchFlagged(); fetchWorkflows(); fetchDeliveryPlans(); fetchPublished(); }, []);

  const handleApprove = async (id: number) => {
    try {
      await axios.patch(`${API_BASE_URL}/api/Catches/${id}/admin-approve`, {}, { headers: authHeader });
      setActionMsg(`✅ Catch #${id} approved and published.`);
      await fetchFlagged();
      setTimeout(() => setActionMsg(''), 4000);
    } catch (err: any) {
      setActionMsg(`❌ Error: ${err.response?.data ?? 'Approval failed.'}`);
    }
  };

  const handleReject = async (id: number) => {
    if (!window.confirm(`Reject and cancel catch #${id}? This cannot be undone.`)) return;
    try {
      await axios.patch(`${API_BASE_URL}/api/Catches/${id}/admin-reject`, {}, { headers: authHeader });
      setActionMsg(`🚫 Catch #${id} rejected and cancelled.`);
      await fetchFlagged();
      setTimeout(() => setActionMsg(''), 4000);
    } catch (err: any) {
      setActionMsg(`❌ Error: ${err.response?.data ?? 'Rejection failed.'}`);
    }
  };

  // ── Summary stats ────────────────────────────────────────────────────────────
  const highRisk   = flagged.filter(c => c.fraudRisk === 'High').length;
  const medRisk    = flagged.filter(c => c.fraudRisk === 'Medium').length;
  const needReview = flagged.filter(c => c.requiresAdminReview).length;

  // ── Render ───────────────────────────────────────────────────────────────────
  return (
    <div className="dashboard-content">
      <h2 style={{ margin: '0 0 6px' }}>🔍 Quality & Fraud Review</h2>
      <p style={{ color: '#64748b', margin: '0 0 24px', fontSize: '0.9rem' }}>
        AI agent validation results — review flagged catches and approve/reject
      </p>

      {/* Summary stats */}
      <div className="stats-row" style={{ marginBottom: '24px' }}>
        <div className="stat-card" style={{ borderTop: '3px solid #ef4444' }}>
          <h3>High Risk</h3>
          <p style={{ color: '#ef4444' }}>{highRisk}</p>
        </div>
        <div className="stat-card" style={{ borderTop: '3px solid #f59e0b' }}>
          <h3>Medium Risk</h3>
          <p style={{ color: '#f59e0b' }}>{medRisk}</p>
        </div>
        <div className="stat-card" style={{ borderTop: '3px solid #f97316' }}>
          <h3>Needs Review</h3>
          <p style={{ color: '#f97316' }}>{needReview}</p>
        </div>
        <div className="stat-card" style={{ borderTop: '3px solid #10b981' }}>
          <h3>Total Flagged</h3>
          <p style={{ color: '#10b981' }}>{flagged.length}</p>
        </div>
      </div>

      {/* Action message */}
      {actionMsg && (
        <div style={{ background: '#f0fdf4', border: '1px solid #6ee7b7', borderRadius: '8px',
          padding: '12px 16px', marginBottom: '20px', fontSize: '0.9rem', color: '#065f46' }}>
          {actionMsg}
        </div>
      )}

      {/* Tabs */}
      <div style={{ display: 'flex', gap: 4, marginBottom: '24px',
        background: '#f1f5f9', borderRadius: '10px', padding: 4, width: 'fit-content' }}>
        {([
          { key: 'flagged',   label: '🚨 Flagged Catches' },
          { key: 'workflows', label: '🤖 AI Workflow Log' },
          { key: 'marketplace', label: '🟢 Published Market' },
          { key: 'logistics', label: '🚚 Delivery Plans' },
        ] as const).map(t => (
          <button key={t.key} onClick={() => { setActiveTab(t.key); }}
            style={{ padding: '8px 18px', borderRadius: '8px', border: 'none', cursor: 'pointer',
              fontWeight: 600, fontSize: '0.85rem',
              background: activeTab === t.key ? 'white' : 'transparent',
              color:      activeTab === t.key ? '#005b96' : '#64748b',
              boxShadow:  activeTab === t.key ? '0 1px 4px rgba(0,0,0,0.1)' : 'none' }}>
            {t.label}
          </button>
        ))}
        <button onClick={() => { fetchFlagged(); fetchWorkflows(); fetchDeliveryPlans(); fetchPublished(); }}
          style={{ padding: '8px 14px', borderRadius: '8px', border: 'none', cursor: 'pointer',
            background: 'transparent', color: 'var(--text-secondary, #64748b)', display: 'flex', alignItems: 'center', gap: 4 }}>
          <RefreshCw size={14} /> Refresh
        </button>
      </div>

      {loading && (
        <div style={{ textAlign: 'center', padding: '40px', color: '#64748b' }}>
          <RefreshCw size={28} style={{ animation: 'spin 1s linear infinite', marginBottom: '8px' }} color="#005b96" />
          <p>Loading…</p>
        </div>
      )}

      {/* ── Flagged Catches Tab ─────────────────────────────────────────── */}
      {activeTab === 'flagged' && !loading && (
        <>
          {flagged.length === 0 ? (
            <div className="workflow-card" style={{ textAlign: 'center', padding: '40px' }}>
              <ShieldCheck size={48} color="#10b981" style={{ marginBottom: '12px' }} />
              <h3 style={{ color: '#065f46' }}>No flagged catches</h3>
              <p style={{ color: '#64748b' }}>All catches are clean — no fraud risk or admin review required.</p>
            </div>
          ) : (
            flagged.map(c => (
              <div key={c.id} className="workflow-card"
                style={{ borderLeftColor: riskBorder(c.fraudRisk), marginBottom: '20px' }}>

                {/* Card header */}
                <div className="card-header">
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap' }}>
                    <h3 style={{ margin: 0 }}>Catch #{c.id} — {c.fishSpecies}</h3>
                    {/* Risk badge */}
                    <span style={{ padding: '3px 12px', borderRadius: '16px', fontSize: '0.78rem',
                      fontWeight: 700, background: riskBg(c.fraudRisk), color: riskColor(c.fraudRisk),
                      border: `1px solid ${riskBorder(c.fraudRisk)}` }}>
                      {riskIcon(c.fraudRisk)} Risk: {c.fraudRisk}
                    </span>
                    {c.requiresAdminReview && (
                      <span style={{ padding: '3px 12px', borderRadius: '16px', fontSize: '0.78rem',
                        fontWeight: 700, background: '#fef3c7', color: '#92400e',
                        border: '1px solid #fde68a' }}>
                        🔔 Review Required
                      </span>
                    )}
                  </div>
                  <span style={{ padding: '4px 12px', borderRadius: '20px', fontSize: '0.78rem',
                    fontWeight: 700, background: '#f1f5f9', color: '#475569' }}>
                    {c.status}
                  </span>
                </div>

                {/* Key details grid */}
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
                  gap: '12px', margin: '16px 0' }}>
                  <div style={{ background: '#f8fafc', borderRadius: '8px', padding: '10px 14px' }}>
                    <p style={{ margin: '0 0 4px', fontSize: '0.72rem', color: '#64748b', textTransform: 'uppercase',
                      letterSpacing: '0.05em', fontWeight: 600 }}>
                      <Scale size={12} style={{ marginRight: 4, verticalAlign: 'middle' }} />Weight
                    </p>
                    <p style={{ margin: 0, fontWeight: 700, color: '#1e293b', fontSize: '0.95rem' }}>
                      Declared: {c.quantityKg}kg
                    </p>
                    {c.verifiedWeightKg > 0 && (
                      <p style={{ margin: '2px 0 0', fontSize: '0.82rem',
                        color: c.weightDiscrepancyPct > 25 ? '#ef4444'
                             : c.weightDiscrepancyPct > 10 ? '#f59e0b' : '#10b981' }}>
                        Verified: {c.verifiedWeightKg}kg
                        {c.weightDiscrepancyPct > 0 && ` (${c.weightDiscrepancyPct}% diff)`}
                      </p>
                    )}
                  </div>

                  <div style={{ background: '#f8fafc', borderRadius: '8px', padding: '10px 14px' }}>
                    <p style={{ margin: '0 0 4px', fontSize: '0.72rem', color: '#64748b',
                      textTransform: 'uppercase', letterSpacing: '0.05em', fontWeight: 600 }}>
                      <Star size={12} style={{ marginRight: 4, verticalAlign: 'middle' }} />Quality
                    </p>
                    <p style={{ margin: 0, fontWeight: 700, color: '#1e293b', fontSize: '0.95rem' }}>
                      Grade: {c.declaredQualityGrade || '—'}
                    </p>
                    <p style={{ margin: '2px 0 0', fontSize: '0.82rem',
                      color: c.inspectionResult === 'Passed' ? '#10b981'
                           : c.inspectionResult === 'Failed' ? '#ef4444' : '#64748b' }}>
                      Inspection: {c.inspectionResult}
                      {c.qualityScore > 0 && ` | Score: ${c.qualityScore}/100`}
                    </p>
                  </div>

                  <div style={{ background: '#f8fafc', borderRadius: '8px', padding: '10px 14px' }}>
                    <p style={{ margin: '0 0 4px', fontSize: '0.72rem', color: '#64748b',
                      textTransform: 'uppercase', letterSpacing: '0.05em', fontWeight: 600 }}>
                      <Activity size={12} style={{ marginRight: 4, verticalAlign: 'middle' }} />Price
                    </p>
                    <p style={{ margin: 0, fontWeight: 700, color: '#1e293b', fontSize: '0.95rem' }}>
                      Rs. {Number(c.askingPricePerKg).toLocaleString()}/kg
                    </p>
                    <p style={{ margin: '2px 0 0', fontSize: '0.82rem', color: '#64748b' }}>
                      {c.location}
                    </p>
                  </div>

                  <div style={{ background: '#f8fafc', borderRadius: '8px', padding: '10px 14px' }}>
                    <p style={{ margin: '0 0 4px', fontSize: '0.72rem', color: '#64748b',
                      textTransform: 'uppercase', letterSpacing: '0.05em', fontWeight: 600 }}>
                      <Fish size={12} style={{ marginRight: 4, verticalAlign: 'middle' }} />Fisherman
                    </p>
                    <p style={{ margin: 0, fontWeight: 700, color: '#1e293b', fontSize: '0.95rem' }}>
                      {c.fisherman?.fullName ?? 'Unknown'}
                    </p>
                    <p style={{ margin: '2px 0 0', fontSize: '0.78rem', color: '#64748b' }}>
                      {c.catchDateTime
                        ? new Date(c.catchDateTime).toLocaleString()
                        : new Date(c.createdAt).toLocaleDateString()}
                    </p>
                  </div>
                </div>

                {/* AI Validation Summary — expandable */}
                {c.validationSummary && (
                  <div style={{ marginBottom: '16px' }}>
                    <button onClick={() => setExpanded(expanded === c.id ? null : c.id)}
                      style={{ display: 'flex', alignItems: 'center', gap: '8px', background: 'none',
                        border: 'none', cursor: 'pointer', color: '#0369a1', fontWeight: 600,
                        fontSize: '0.82rem', padding: '6px 0' }}>
                      <Eye size={14} />
                      {expanded === c.id ? 'Hide' : 'Show'} AI Validation Report
                      {expanded === c.id ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
                    </button>
                    {expanded === c.id && (
                      <pre style={{ background: '#0f172a', color: '#e2e8f0', borderRadius: '8px',
                        padding: '16px', fontSize: '0.78rem', lineHeight: '1.7',
                        overflowX: 'auto', whiteSpace: 'pre-wrap', margin: 0 }}>
                        {c.validationSummary}
                      </pre>
                    )}
                  </div>
                )}

                {/* Seller note */}
                {c.sellerNote && (
                  <div style={{ background: '#fefce8', border: '1px solid #fde047', borderRadius: '8px',
                    padding: '10px 14px', marginBottom: '16px', fontSize: '0.82rem', color: '#713f12' }}>
                    <strong>Seller Note:</strong> {c.sellerNote}
                  </div>
                )}

                {/* Approve / Reject buttons */}
                {c.requiresAdminReview && c.status !== 'Cancelled' && (
                  <div style={{ display: 'flex', gap: '12px', paddingTop: '14px',
                    borderTop: '1px solid #f1f5f9', flexWrap: 'wrap' }}>
                    <button onClick={() => handleApprove(c.id)} className="btn-approve"
                      style={{ display: 'flex', alignItems: 'center', gap: '8px',
                        padding: '10px 24px', borderRadius: '8px', fontWeight: 700 }}>
                      <CheckCircle size={16} /> Approve & Publish
                    </button>
                    <button onClick={() => handleReject(c.id)} className="btn-reject"
                      style={{ display: 'flex', alignItems: 'center', gap: '8px',
                        padding: '10px 24px', borderRadius: '8px', fontWeight: 700 }}>
                      <XCircle size={16} /> Reject & Cancel
                    </button>
                  </div>
                )}

                {/* Already reviewed */}
                {!c.requiresAdminReview && (
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px',
                    paddingTop: '12px', borderTop: '1px solid #f1f5f9',
                    color: '#64748b', fontSize: '0.82rem' }}>
                    <ShieldCheck size={14} color="#10b981" />
                    Already reviewed — no further action required
                  </div>
                )}
              </div>
            ))
          )}
        </>
      )}

      {/* ── Marketplace Tab ─────────────────────────────────────────── */}
      {activeTab === 'marketplace' && !loading && (
        <>
          <p style={{ color: 'var(--text-secondary, #64748b)', fontSize: '0.85rem', marginBottom: '20px' }}>
            Live view of all published and active catches currently visible to buyers on the marketplace.
          </p>
          {published.length === 0 ? (
            <div className="workflow-card" style={{ textAlign: 'center', padding: '40px' }}>
              <Fish size={48} color="var(--primary, #10b981)" style={{ marginBottom: '12px' }} />
              <h3 style={{ color: 'var(--text-primary)' }}>No published catches</h3>
              <p style={{ color: 'var(--text-secondary)' }}>There are no active catches in the marketplace.</p>
            </div>
          ) : (
            published.map(c => (
              <div key={c.id} className="workflow-card" style={{ marginBottom: '20px' }}>
                <div className="card-header">
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <h3 style={{ margin: 0, color: 'var(--text-primary)' }}>Catch #{c.id} — {c.fishSpecies}</h3>
                  </div>
                  <span style={{ padding: '4px 12px', borderRadius: '20px', fontSize: '0.78rem',
                    fontWeight: 700, background: '#d1fae5', color: '#065f46' }}>
                    {c.status}
                  </span>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
                  gap: '12px', margin: '16px 0' }}>
                  <div style={{ background: 'var(--bg-tertiary, #f8fafc)', borderRadius: '8px', padding: '10px 14px' }}>
                    <p style={{ margin: '0 0 4px', fontSize: '0.72rem', color: 'var(--text-secondary)', textTransform: 'uppercase', fontWeight: 600 }}>Weight</p>
                    <p style={{ margin: 0, fontWeight: 700, color: 'var(--text-primary)', fontSize: '0.95rem' }}>{c.quantityKg}kg</p>
                  </div>
                  <div style={{ background: 'var(--bg-tertiary, #f8fafc)', borderRadius: '8px', padding: '10px 14px' }}>
                    <p style={{ margin: '0 0 4px', fontSize: '0.72rem', color: 'var(--text-secondary)', textTransform: 'uppercase', fontWeight: 600 }}>Quality Grade</p>
                    <p style={{ margin: 0, fontWeight: 700, color: 'var(--text-primary)', fontSize: '0.95rem' }}>{c.declaredQualityGrade}</p>
                  </div>
                  <div style={{ background: 'var(--bg-tertiary, #f8fafc)', borderRadius: '8px', padding: '10px 14px' }}>
                    <p style={{ margin: '0 0 4px', fontSize: '0.72rem', color: 'var(--text-secondary)', textTransform: 'uppercase', fontWeight: 600 }}>Asking Price</p>
                    <p style={{ margin: 0, fontWeight: 700, color: 'var(--text-primary)', fontSize: '0.95rem' }}>Rs. {Number(c.askingPricePerKg).toLocaleString()}/kg</p>
                  </div>
                  <div style={{ background: 'var(--bg-tertiary, #f8fafc)', borderRadius: '8px', padding: '10px 14px' }}>
                    <p style={{ margin: '0 0 4px', fontSize: '0.72rem', color: 'var(--text-secondary)', textTransform: 'uppercase', fontWeight: 600 }}>Location</p>
                    <p style={{ margin: 0, fontWeight: 700, color: 'var(--text-primary)', fontSize: '0.95rem' }}>{c.location}</p>
                  </div>
                </div>
              </div>
            ))
          )}
        </>
      )}

      {/* ── AI Workflow Log Tab ─────────────────────────────────────────── */}
      {activeTab === 'workflows' && !loading && (
        <>
          <p style={{ color: '#64748b', fontSize: '0.85rem', marginBottom: '20px' }}>
            All catches that have been processed by the AI agent — showing validation summaries.
          </p>
          {(workflows as any[]).length === 0 ? (
            <div className="workflow-card" style={{ textAlign: 'center', padding: '40px' }}>
              <Clock size={48} color="#94a3b8" style={{ marginBottom: '12px' }} />
              <h3 style={{ color: '#475569' }}>No workflow logs yet</h3>
              <p style={{ color: '#94a3b8' }}>Start the AI agent and submit a catch to see logs here.</p>
            </div>
          ) : (
            (workflows as any[]).map((c: any) => (
              <div key={c.id} className="workflow-card"
                style={{ borderLeftColor: riskBorder(c.fraudRisk ?? 'Low'), marginBottom: '16px' }}>
                <div className="card-header">
                  <h3 style={{ margin: 0, fontSize: '0.95rem' }}>
                    Catch #{c.id} — {c.fishSpecies} ({c.quantityKg}kg)
                  </h3>
                  <div style={{ display: 'flex', gap: '8px' }}>
                    {c.fraudRisk && c.fraudRisk !== 'Unassessed' && (
                      <span style={{ padding: '3px 10px', borderRadius: '12px', fontSize: '0.75rem',
                        fontWeight: 700, background: riskBg(c.fraudRisk), color: riskColor(c.fraudRisk) }}>
                        {riskIcon(c.fraudRisk)} {c.fraudRisk}
                      </span>
                    )}
                    <span style={{ padding: '3px 10px', borderRadius: '12px', fontSize: '0.75rem',
                      fontWeight: 600, background: '#f1f5f9', color: '#475569' }}>
                      {c.status}
                    </span>
                  </div>
                </div>

                {c.validationSummary && (
                  <div style={{ marginTop: '12px' }}>
                    <button onClick={() => setExpanded(expanded === c.id ? null : c.id)}
                      style={{ display: 'flex', alignItems: 'center', gap: '6px', background: 'none',
                        border: 'none', cursor: 'pointer', color: '#0369a1',
                        fontWeight: 600, fontSize: '0.8rem', padding: '4px 0' }}>
                      <Eye size={13} />
                      {expanded === c.id ? 'Hide' : 'View'} Validation Report
                      {expanded === c.id ? <ChevronUp size={13} /> : <ChevronDown size={13} />}
                    </button>
                    {expanded === c.id && (
                      <pre style={{ background: '#0f172a', color: '#e2e8f0', borderRadius: '8px',
                        padding: '14px', fontSize: '0.76rem', lineHeight: '1.7',
                        overflowX: 'auto', whiteSpace: 'pre-wrap', marginTop: '8px' }}>
                        {c.validationSummary}
                      </pre>
                    )}
                  </div>
                )}
              </div>
            ))
          )}
        </>
      )}

      {/* ── Delivery Plans Tab ───────────────────────────────────────── */}
      {activeTab === 'logistics' && !loading && (
        <>
          {/* Live weather for key fishing ports */}
          <WeatherWidget />
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 20 }}>
            <Truck size={20} color="#8b5cf6" />
            <h3 style={{ margin: 0 }}>
              AI Delivery Plans ({deliveryPlans.length})
            </h3>
            <span style={{ padding: '2px 10px', borderRadius: 12, fontSize: '0.78rem',
              fontWeight: 700, background: '#ede9fe', color: '#6d28d9' }}>
              {deliveryPlans.filter(p => p.status === 'PendingApproval').length} pending
            </span>
          </div>

          {deliveryPlans.length === 0 ? (
            <div className="workflow-card" style={{ textAlign: 'center', padding: 40 }}>
              <Truck size={48} color="#94a3b8" style={{ marginBottom: 12 }} />
              <h3 style={{ color: '#475569' }}>No delivery plans yet</h3>
              <p style={{ color: '#94a3b8' }}>
                Delivery plans are created when the Logistics Agent runs after a bid is accepted.
              </p>
            </div>
          ) : (
            deliveryPlans.map(plan => (
              <div key={plan.id} className="workflow-card" style={{ marginBottom: 20,
                borderLeftColor: plan.status === 'PendingApproval' ? '#f59e0b'
                               : plan.status === 'Scheduled' ? '#10b981'
                               : plan.status === 'Delivered' ? '#8b5cf6'
                               : '#ef4444' }}>

                {/* Header */}
                <div className="card-header">
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
                    <h3 style={{ margin: 0, fontSize: '0.95rem' }}>
                      🚚 {plan.planId}
                    </h3>
                    <span style={{ padding: '3px 10px', borderRadius: 12, fontSize: '0.75rem',
                      fontWeight: 700,
                      background: plan.status === 'PendingApproval' ? '#fef3c7'
                                : plan.status === 'Scheduled' ? '#d1fae5'
                                : plan.status === 'Delivered' ? '#ede9fe' : '#fee2e2',
                      color: plan.status === 'PendingApproval' ? '#92400e'
                           : plan.status === 'Scheduled' ? '#065f46'
                           : plan.status === 'Delivered' ? '#4c1d95' : '#991b1b' }}>
                      {plan.status === 'PendingApproval' ? '⏳ Pending Approval'
                     : plan.status === 'Scheduled' ? '✅ Scheduled'
                     : plan.status === 'Delivered' ? '🏁 Delivered'
                     : '❌ ' + plan.status}
                    </span>
                  </div>
                  <span style={{ fontSize: '0.78rem', color: '#94a3b8' }}>
                    Catch #{plan.catchId}
                  </span>
                </div>

                {/* Details grid */}
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))',
                  gap: 10, margin: '14px 0' }}>
                  {[
                    { icon: '🚛', label: 'Vehicle',      value: plan.vehicleCode },
                    { icon: '👤', label: 'Driver',       value: plan.driverCode },
                    { icon: '🧊', label: 'Cold Storage', value: plan.coldStorageCode },
                    { icon: '📍', label: 'Route',        value: plan.selectedRoute },
                    { icon: '📏', label: 'Distance',     value: `${plan.distanceKm} km` },
                    { icon: '⏱️', label: 'Est. Time',    value: `${plan.estimatedMinutes} min` },
                    { icon: '🕐', label: 'Pickup',       value: plan.pickupTime ? new Date(plan.pickupTime).toLocaleTimeString([], {hour:'2-digit',minute:'2-digit'}) : '—' },
                    { icon: '🏁', label: 'ETA',          value: plan.estimatedETA ? new Date(plan.estimatedETA).toLocaleTimeString([], {hour:'2-digit',minute:'2-digit'}) : '—' },
                  ].map(d => (
                    <div key={d.label} style={{ background: '#f8fafc', borderRadius: 8, padding: '10px 12px' }}>
                      <p style={{ margin: '0 0 3px', fontSize: '0.7rem', color: '#64748b',
                        textTransform: 'uppercase', letterSpacing: '0.05em', fontWeight: 600 }}>
                        {d.label}
                      </p>
                      <p style={{ margin: 0, fontWeight: 700, color: '#1e293b', fontSize: '0.88rem' }}>
                        {d.icon} {d.value}
                      </p>
                    </div>
                  ))}
                </div>

                {/* Route: pickup → delivery */}
                <div style={{ display: 'flex', alignItems: 'center', gap: 8,
                  background: '#f0f9ff', borderRadius: 8, padding: '10px 14px', marginBottom: 12 }}>
                  <MapPin size={14} color="#0284c7" />
                  <span style={{ fontSize: '0.85rem', color: '#0369a1', fontWeight: 600 }}>
                    {plan.pickupLocation}
                  </span>
                  <span style={{ color: '#94a3b8' }}>→</span>
                  <span style={{ fontSize: '0.85rem', color: '#0369a1', fontWeight: 600 }}>
                    {plan.deliveryLocation}
                  </span>
                </div>

                {/* Weather note */}
                {plan.weatherNote && (
                  <div style={{ background: '#fefce8', border: '1px solid #fde047',
                    borderRadius: 8, padding: '8px 12px', marginBottom: 12,
                    fontSize: '0.82rem', color: '#713f12' }}>
                    🌤️ <strong>Weather:</strong> {plan.weatherNote}
                  </div>
                )}

                {/* AI Reasoning */}
                {plan.agentReasoning && (
                  <div style={{ marginBottom: 14 }}>
                    <button onClick={() => setExpanded(expanded === plan.id ? null : plan.id)}
                      style={{ display: 'flex', alignItems: 'center', gap: 6, background: 'none',
                        border: 'none', cursor: 'pointer', color: '#7c3aed',
                        fontWeight: 600, fontSize: '0.82rem', padding: '4px 0' }}>
                      <Eye size={13} />
                      {expanded === plan.id ? 'Hide' : 'Show'} AI Reasoning
                      {expanded === plan.id ? <ChevronUp size={13} /> : <ChevronDown size={13} />}
                    </button>
                    {expanded === plan.id && (
                      <pre style={{ background: '#0f172a', color: '#e2e8f0', borderRadius: 8,
                        padding: 14, fontSize: '0.76rem', lineHeight: 1.7,
                        overflowX: 'auto', whiteSpace: 'pre-wrap', marginTop: 8 }}>
                        {plan.agentReasoning}
                      </pre>
                    )}
                  </div>
                )}

                {/* Admin note */}
                {plan.adminNote && (
                  <div style={{ background: '#f0fdf4', border: '1px solid #6ee7b7',
                    borderRadius: 8, padding: '8px 12px', marginBottom: 12,
                    fontSize: '0.82rem', color: '#065f46' }}>
                    📝 <strong>Admin Note:</strong> {plan.adminNote}
                  </div>
                )}

                {/* Action buttons */}
                {plan.status === 'PendingApproval' && (
                  <div style={{ display: 'flex', gap: 10, paddingTop: 12,
                    borderTop: '1px solid #f1f5f9', flexWrap: 'wrap' }}>
                    <button onClick={() => handleApprovePlan(plan.id)} className="btn-approve"
                      style={{ display: 'flex', alignItems: 'center', gap: 8,
                        padding: '10px 22px', borderRadius: 8, fontWeight: 700 }}>
                      <CheckCircle size={16} /> Approve & Schedule
                    </button>
                    <button onClick={() => handleRejectPlan(plan.id)} className="btn-reject"
                      style={{ display: 'flex', alignItems: 'center', gap: 8,
                        padding: '10px 22px', borderRadius: 8, fontWeight: 700 }}>
                      <XCircle size={16} /> Reject Plan
                    </button>
                  </div>
                )}

                {plan.status === 'Scheduled' && (
                  <div style={{ display: 'flex', gap: 10, paddingTop: 12,
                    borderTop: '1px solid #f1f5f9' }}>
                    <button onClick={() => handleCompletePlan(plan.id)}
                      className="btn-primary"
                      style={{ display: 'flex', alignItems: 'center', gap: 8,
                        padding: '8px 20px', marginTop: 0, borderRadius: 8 }}>
                      🏁 Mark as Delivered
                    </button>
                  </div>
                )}
              </div>
            ))
          )}
        </>
      )}

      <style>{`@keyframes spin { from{transform:rotate(0deg)} to{transform:rotate(360deg)} }`}</style>
    </div>
  );
};
