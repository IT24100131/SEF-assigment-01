import React, { useState, useEffect } from 'react';
import {
  CheckCircle, XCircle, RefreshCw,
  ShieldCheck, Eye, ChevronDown, ChevronUp,
  Activity, Fish, Scale, Star, Clock, Truck, MapPin, X, Plus,
} from 'lucide-react';
import axios from 'axios';
import { API_BASE_URL, formatErrorMessage } from '../../config/api';

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
  photoUrl?: string;
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
  defaultTab?: 'flagged' | 'workflows' | 'logistics';
  onTabChange?: (tab: string) => void;
}> = ({ defaultTab = 'flagged' }) => {
  const [activeTab,     setActiveTab]     = useState<'flagged' | 'workflows' | 'logistics'>(defaultTab);

  // Sync when parent sidebar tab changes
  useEffect(() => { setActiveTab(defaultTab as any); }, [defaultTab]);
  const [flagged,       setFlagged]       = useState<FlaggedCatch[]>([]);
  const [workflows,     setWorkflows]     = useState<any[]>([]);
  const [deliveryPlans, setDeliveryPlans] = useState<DeliveryPlan[]>([]);
  const [loading,       setLoading]       = useState(false);
  const [actionMsg,     setActionMsg]     = useState('');
  const [expanded,      setExpanded]      = useState<number | null>(null);
  const [selectedCatch, setSelectedCatch] = useState<FlaggedCatch | null>(null);
  const [filterRisk,    setFilterRisk]    = useState<'all' | 'high' | 'medium' | 'review'>('all');

  // Manual Delivery Plan Creation State
  const [showCreatePlan, setShowCreatePlan] = useState(false);
  const [resourcesVehicles, setResourcesVehicles] = useState<any[]>([]);
  const [resourcesDrivers, setResourcesDrivers] = useState<any[]>([]);
  const [resourcesStorage, setResourcesStorage] = useState<any[]>([]);
  const [createPlanData, setCreatePlanData] = useState({
    catchId: '',
    vehicleCode: 'V01',
    driverCode: 'D01',
    coldStorageCode: 'C01',
    pickupLocation: 'Negombo Pier',
    deliveryLocation: 'Colombo Central Market',
    selectedRoute: 'Route A (Direct Highway)',
    distanceKm: '45',
    estimatedMinutes: '60',
    weatherNote: 'Clear conditions, optimal transit window',
  });

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

  const fetchWorkflows = async () => {
    setLoading(true);
    try {
      const res = await axios.get<any>(
        `${API_BASE_URL}/api/Catches?pageSize=100`, { headers: authHeader }
      );
      const list = Array.isArray(res.data)
        ? res.data
        : (res.data?.items ?? res.data?.data ?? []);
      const withSummary = list.filter((c: any) => c.validationSummary);
      setWorkflows(withSummary);
    } catch {
      setWorkflows([]);
    } finally {
      setLoading(false);
    }
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
      setActionMsg(`❌ ${formatErrorMessage(err, 'Delivery plan approval failed.')}`);
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
      setActionMsg(`❌ ${formatErrorMessage(err, 'Delivery plan rejection failed.')}`);
    }
  };

  const handleCompletePlan = async (id: number) => {
    try {
      await axios.patch(`${API_BASE_URL}/api/Logistics/plans/${id}/complete`, {}, { headers: authHeader });
      setActionMsg(`🏁 Delivery #${id} marked as delivered.`);
      await fetchDeliveryPlans();
      setTimeout(() => setActionMsg(''), 4000);
    } catch (err: any) {
      setActionMsg(`❌ ${formatErrorMessage(err, 'Marking delivery complete failed.')}`);
    }
  };

  const fetchLogisticsResources = async () => {
    try {
      const [vRes, dRes, sRes] = await Promise.all([
        axios.get(`${API_BASE_URL}/api/Logistics/vehicles`),
        axios.get(`${API_BASE_URL}/api/Logistics/drivers`),
        axios.get(`${API_BASE_URL}/api/Logistics/storage`),
      ]);
      setResourcesVehicles(vRes.data);
      setResourcesDrivers(dRes.data);
      setResourcesStorage(sRes.data);
    } catch {}
  };

  const handleCreatePlanSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!createPlanData.catchId) {
      alert('Please enter a Catch ID.');
      return;
    }
    try {
      await axios.post(`${API_BASE_URL}/api/Logistics/plans`, {
        catchId: parseInt(createPlanData.catchId),
        vehicleCode: createPlanData.vehicleCode,
        driverCode: createPlanData.driverCode,
        coldStorageCode: createPlanData.coldStorageCode,
        pickupLocation: createPlanData.pickupLocation,
        deliveryLocation: createPlanData.deliveryLocation,
        selectedRoute: createPlanData.selectedRoute,
        distanceKm: parseFloat(createPlanData.distanceKm) || 0,
        estimatedMinutes: parseInt(createPlanData.estimatedMinutes) || 60,
        weatherNote: createPlanData.weatherNote,
        agentReasoning: 'Manually created by Dispatcher / Admin.',
        status: 'PendingApproval',
      }, { headers: authHeader });
      setActionMsg('✅ Delivery plan created successfully (Pending Approval).');
      setShowCreatePlan(false);
      setCreatePlanData({
        catchId: '',
        vehicleCode: 'V01',
        driverCode: 'D01',
        coldStorageCode: 'C01',
        pickupLocation: 'Negombo Pier',
        deliveryLocation: 'Colombo Central Market',
        selectedRoute: 'Route A (Direct Highway)',
        distanceKm: '45',
        estimatedMinutes: '60',
        weatherNote: 'Clear conditions, optimal transit window',
      });
      await fetchDeliveryPlans();
      setTimeout(() => setActionMsg(''), 4000);
    } catch (err: any) {
      alert(formatErrorMessage(err, 'Failed to create delivery plan.'));
    }
  };

  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { fetchFlagged(); fetchWorkflows(); fetchDeliveryPlans(); }, []);

  const handleApprove = async (id: number) => {
    try {
      await axios.patch(`${API_BASE_URL}/api/Catches/${id}/admin-approve`, {}, { headers: authHeader });
      setActionMsg(`✅ Catch #${id} approved and published.`);
      await fetchFlagged();
      setTimeout(() => setActionMsg(''), 4000);
    } catch (err: any) {
      setActionMsg(`❌ ${formatErrorMessage(err, 'Catch approval failed.')}`);
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
      setActionMsg(`❌ ${formatErrorMessage(err, 'Catch rejection failed.')}`);
    }
  };

  // ── Summary stats ────────────────────────────────────────────────────────────
  const highRisk   = flagged.filter(c => c.fraudRisk === 'High').length;
  const medRisk    = flagged.filter(c => c.fraudRisk === 'Medium').length;
  const needReview = flagged.filter(c => c.requiresAdminReview).length;

  const displayedFlagged = flagged.filter(c => {
    if (filterRisk === 'high')   return c.fraudRisk === 'High';
    if (filterRisk === 'medium') return c.fraudRisk === 'Medium';
    if (filterRisk === 'review') return c.requiresAdminReview;
    return true;
  });

  // ── Full Detail Modal ───────────────────────────────────────────────────────
  const CatchDetailModal = () => {
    if (!selectedCatch) return null;
    const c = selectedCatch;
    return (
      <div style={{
        position: 'fixed', inset: 0, background: 'rgba(15,23,42,0.65)', backdropFilter: 'blur(3px)',
        zIndex: 9999, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 20
      }}>
        <div style={{
          background: 'white', borderRadius: 16, width: '100%', maxWidth: 640,
          maxHeight: '90vh', overflowY: 'auto', boxShadow: '0 25px 50px -12px rgba(0,0,0,0.25)',
          border: `2px solid ${riskBorder(c.fraudRisk)}`
        }}>
          {/* Header */}
          <div style={{
            padding: '20px 24px', borderBottom: '1px solid #e2e8f0', display: 'flex',
            justifyContent: 'space-between', alignItems: 'center', background: '#f8fafc'
          }}>
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <h3 style={{ margin: 0, fontSize: '1.2rem', color: '#0f172a' }}>
                  Catch #{c.id} — {c.fishSpecies}
                </h3>
                <span style={{
                  padding: '3px 12px', borderRadius: 16, fontSize: '0.75rem', fontWeight: 700,
                  background: riskBg(c.fraudRisk), color: riskColor(c.fraudRisk),
                  border: `1px solid ${riskBorder(c.fraudRisk)}`
                }}>
                  {riskIcon(c.fraudRisk)} {c.fraudRisk} Risk
                </span>
              </div>
              <p style={{ margin: '4px 0 0', fontSize: '0.8rem', color: '#64748b' }}>
                Fisherman: {c.fisherman?.fullName ?? 'Unknown'} · Location: {c.location}
              </p>
            </div>
            <button onClick={() => setSelectedCatch(null)}
              style={{ background: '#f1f5f9', border: 'none', borderRadius: 8, padding: 8, cursor: 'pointer', color: '#64748b' }}>
              <X size={20} />
            </button>
          </div>

          <div style={{ padding: '24px' }}>
            {c.photoUrl && (
              <img src={c.photoUrl} alt="catch" style={{
                width: '100%', maxHeight: 220, objectFit: 'cover', borderRadius: 10,
                marginBottom: 20, border: '1px solid #e2e8f0'
              }} />
            )}

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 20 }}>
              <div style={{ background: '#f8fafc', padding: '12px 14px', borderRadius: 10, border: '1px solid #e2e8f0' }}>
                <span style={{ fontSize: '0.72rem', color: '#64748b', fontWeight: 700, textTransform: 'uppercase' }}>Weight</span>
                <p style={{ margin: '4px 0 0', fontWeight: 800, color: '#0f172a', fontSize: '1.05rem' }}>{c.quantityKg} kg</p>
                {c.verifiedWeightKg > 0 && (
                  <p style={{ margin: '2px 0 0', fontSize: '0.75rem', color: c.weightDiscrepancyPct > 25 ? '#ef4444' : '#d97706', fontWeight: 600 }}>
                    Verified: {c.verifiedWeightKg}kg ({c.weightDiscrepancyPct}% diff)
                  </p>
                )}
              </div>

              <div style={{ background: '#f8fafc', padding: '12px 14px', borderRadius: 10, border: '1px solid #e2e8f0' }}>
                <span style={{ fontSize: '0.72rem', color: '#64748b', fontWeight: 700, textTransform: 'uppercase' }}>Quality Score</span>
                <p style={{ margin: '4px 0 0', fontWeight: 800, color: '#0f172a', fontSize: '1.05rem' }}>{c.qualityScore}/100</p>
                <p style={{ margin: '2px 0 0', fontSize: '0.75rem', color: '#64748b' }}>
                  Grade {c.declaredQualityGrade || '—'} · {c.inspectionResult}
                </p>
              </div>

              <div style={{ background: '#f8fafc', padding: '12px 14px', borderRadius: 10, border: '1px solid #e2e8f0' }}>
                <span style={{ fontSize: '0.72rem', color: '#64748b', fontWeight: 700, textTransform: 'uppercase' }}>Asking Price</span>
                <p style={{ margin: '4px 0 0', fontWeight: 800, color: '#0f172a', fontSize: '1.05rem' }}>Rs. {Number(c.askingPricePerKg).toLocaleString()}</p>
                <p style={{ margin: '2px 0 0', fontSize: '0.75rem', color: '#64748b' }}>Total: Rs. {(c.quantityKg * c.askingPricePerKg).toLocaleString()}</p>
              </div>
            </div>

            {c.validationSummary && (
              <div style={{ marginBottom: 20 }}>
                <h4 style={{ margin: '0 0 8px', fontSize: '0.85rem', color: '#0369a1', fontWeight: 700, display: 'flex', alignItems: 'center', gap: 6 }}>
                  <Activity size={15} /> AI Agent Quality & Fraud Validation Report
                </h4>
                <pre style={{
                  background: '#0f172a', color: '#f1f5f9', borderRadius: 10, padding: 16,
                  fontSize: '0.8rem', lineHeight: '1.7', whiteSpace: 'pre-wrap', margin: 0,
                  fontFamily: 'monospace'
                }}>
                  {c.validationSummary}
                </pre>
              </div>
            )}

            <div style={{ display: 'flex', gap: 12, justifyContent: 'flex-end', paddingTop: 16, borderTop: '1px solid #f1f5f9' }}>
              <button className="btn-outline" onClick={() => setSelectedCatch(null)} style={{ padding: '9px 18px' }}>
                Close
              </button>
              {c.requiresAdminReview && (
                <>
                  <button className="btn-approve" onClick={() => { handleApprove(c.id); setSelectedCatch(null); }}
                    style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '9px 20px', fontWeight: 700 }}>
                    <CheckCircle size={16} /> Approve & Publish
                  </button>
                  <button className="btn-reject" onClick={() => { handleReject(c.id); setSelectedCatch(null); }}
                    style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '9px 20px', fontWeight: 700 }}>
                    <XCircle size={16} /> Reject & Cancel
                  </button>
                </>
              )}
            </div>
          </div>
        </div>
      </div>
    );
  };

  // ── Render ───────────────────────────────────────────────────────────────────
  return (
    <div className="dashboard-content">
      <CatchDetailModal />

      <h2 style={{ margin: '0 0 6px' }}>🔍 Quality & Fraud Review</h2>
      <p style={{ color: '#64748b', margin: '0 0 24px', fontSize: '0.9rem' }}>
        AI agent validation results — review flagged catches and approve/reject
      </p>

      {/* Summary stats — clickable filter cards */}
      <div className="stats-row" style={{ marginBottom: '24px' }}>
        <div
          className="stat-card"
          onClick={() => { setFilterRisk(filterRisk === 'high' ? 'all' : 'high'); setActiveTab('flagged'); }}
          style={{
            borderTop: '3px solid #ef4444',
            cursor: 'pointer',
            transition: 'all 0.2s ease',
            transform: filterRisk === 'high' ? 'translateY(-3px)' : 'none',
            boxShadow: filterRisk === 'high' ? '0 6px 16px rgba(239,68,68,0.25)' : 'none',
            background: filterRisk === 'high' ? '#fef2f2' : 'white',
            outline: filterRisk === 'high' ? '2px solid #ef4444' : 'none',
          }}
          title="Click to view only High Risk catches"
        >
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <h3>High Risk</h3>
            <span style={{ fontSize: '0.75rem', color: '#ef4444', fontWeight: 600 }}>Filter 🔍</span>
          </div>
          <p style={{ color: '#ef4444', margin: '6px 0 0' }}>{highRisk}</p>
        </div>

        <div
          className="stat-card"
          onClick={() => { setFilterRisk(filterRisk === 'medium' ? 'all' : 'medium'); setActiveTab('flagged'); }}
          style={{
            borderTop: '3px solid #f59e0b',
            cursor: 'pointer',
            transition: 'all 0.2s ease',
            transform: filterRisk === 'medium' ? 'translateY(-3px)' : 'none',
            boxShadow: filterRisk === 'medium' ? '0 6px 16px rgba(245,158,11,0.25)' : 'none',
            background: filterRisk === 'medium' ? '#fffbeb' : 'white',
            outline: filterRisk === 'medium' ? '2px solid #f59e0b' : 'none',
          }}
          title="Click to view only Medium Risk catches"
        >
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <h3>Medium Risk</h3>
            <span style={{ fontSize: '0.75rem', color: '#f59e0b', fontWeight: 600 }}>Filter 🔍</span>
          </div>
          <p style={{ color: '#f59e0b', margin: '6px 0 0' }}>{medRisk}</p>
        </div>

        <div
          className="stat-card"
          onClick={() => { setFilterRisk(filterRisk === 'review' ? 'all' : 'review'); setActiveTab('flagged'); }}
          style={{
            borderTop: '3px solid #f97316',
            cursor: 'pointer',
            transition: 'all 0.2s ease',
            transform: filterRisk === 'review' ? 'translateY(-3px)' : 'none',
            boxShadow: filterRisk === 'review' ? '0 6px 16px rgba(249,115,22,0.25)' : 'none',
            background: filterRisk === 'review' ? '#fff7ed' : 'white',
            outline: filterRisk === 'review' ? '2px solid #f97316' : 'none',
          }}
          title="Click to view catches that need Admin Review"
        >
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <h3>Needs Review</h3>
            <span style={{ fontSize: '0.75rem', color: '#f97316', fontWeight: 600 }}>Filter 🔍</span>
          </div>
          <p style={{ color: '#f97316', margin: '6px 0 0' }}>{needReview}</p>
        </div>

        <div
          className="stat-card"
          onClick={() => { setFilterRisk('all'); setActiveTab('flagged'); }}
          style={{
            borderTop: '3px solid #10b981',
            cursor: 'pointer',
            transition: 'all 0.2s ease',
            transform: filterRisk === 'all' ? 'translateY(-3px)' : 'none',
            boxShadow: filterRisk === 'all' ? '0 6px 16px rgba(16,185,129,0.25)' : 'none',
            background: filterRisk === 'all' ? '#f0fdf4' : 'white',
            outline: filterRisk === 'all' ? '2px solid #10b981' : 'none',
          }}
          title="Click to view All Flagged catches"
        >
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <h3>Total Flagged</h3>
            <span style={{ fontSize: '0.75rem', color: '#10b981', fontWeight: 600 }}>View All 👁️</span>
          </div>
          <p style={{ color: '#10b981', margin: '6px 0 0' }}>{flagged.length}</p>
        </div>
      </div>

      {/* Action message */}
      {actionMsg && (
        <div style={{
          background: actionMsg.startsWith('❌') ? '#fef2f2' : '#f0fdf4',
          border: `1px solid ${actionMsg.startsWith('❌') ? '#fca5a5' : '#6ee7b7'}`,
          borderRadius: '8px',
          padding: '12px 16px',
          marginBottom: '20px',
          fontSize: '0.9rem',
          color: actionMsg.startsWith('❌') ? '#991b1b' : '#065f46',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center'
        }}>
          <span>{actionMsg}</span>
          <button
            onClick={() => setActionMsg('')}
            style={{
              background: 'transparent',
              border: 'none',
              cursor: 'pointer',
              color: 'inherit',
              fontWeight: 'bold',
              fontSize: '1rem',
              padding: '0 4px'
            }}
            title="Dismiss"
          >
            ✕
          </button>
        </div>
      )}

      {/* Tabs */}
      <div style={{ display: 'flex', gap: 4, marginBottom: '24px',
        background: '#f1f5f9', borderRadius: '10px', padding: 4, width: 'fit-content' }}>
        {([
          { key: 'flagged',   label: '🚨 Flagged Catches' },
          { key: 'workflows', label: '🤖 AI Workflow Log' },
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
        <button onClick={() => { fetchFlagged(); fetchWorkflows(); fetchDeliveryPlans(); }}
          style={{ padding: '8px 14px', borderRadius: '8px', border: 'none', cursor: 'pointer',
            background: 'transparent', color: '#64748b', display: 'flex', alignItems: 'center', gap: 4 }}>
          <RefreshCw size={14} /> Refresh
        </button>
      </div>

      {/* Active filter notification */}
      {activeTab === 'flagged' && filterRisk !== 'all' && (
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          background: '#f8fafc', border: '1px solid #cbd5e1', borderRadius: '8px',
          padding: '10px 16px', marginBottom: '20px'
        }}>
          <span style={{ fontSize: '0.85rem', color: '#334155', fontWeight: 600 }}>
            Filtering: <strong>{filterRisk === 'high' ? '🚨 High Risk' : filterRisk === 'medium' ? '⚠️ Medium Risk' : '🔔 Needs Review'}</strong> ({displayedFlagged.length} catches)
          </span>
          <button onClick={() => setFilterRisk('all')}
            style={{ background: 'none', border: 'none', color: '#0369a1', cursor: 'pointer',
              fontWeight: 700, fontSize: '0.82rem' }}>
            Show All ({flagged.length}) ✕
          </button>
        </div>
      )}

      {loading && (
        <div style={{ textAlign: 'center', padding: '40px', color: '#64748b' }}>
          <RefreshCw size={28} style={{ animation: 'spin 1s linear infinite', marginBottom: '8px' }} color="#005b96" />
          <p>Loading…</p>
        </div>
      )}

      {/* ── Flagged Catches Tab ─────────────────────────────────────────── */}
      {activeTab === 'flagged' && !loading && (
        <>
          {displayedFlagged.length === 0 ? (
            <div className="workflow-card" style={{ textAlign: 'center', padding: '40px' }}>
              <ShieldCheck size={48} color="#10b981" style={{ marginBottom: '12px' }} />
              <h3 style={{ color: '#065f46' }}>No catches in this category</h3>
              <p style={{ color: '#64748b' }}>Try clicking "Show All" or selecting a different filter above.</p>
              {filterRisk !== 'all' && (
                <button onClick={() => setFilterRisk('all')} className="btn-primary" style={{ marginTop: 12 }}>
                  Show All Catches
                </button>
              )}
            </div>
          ) : (
            displayedFlagged.map(c => (
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

                {/* Approve / Reject / View Details buttons */}
                <div style={{ display: 'flex', gap: '10px', paddingTop: '14px',
                  borderTop: '1px solid #f1f5f9', flexWrap: 'wrap', alignItems: 'center' }}>
                  <button onClick={() => setSelectedCatch(c)} className="btn-outline"
                    style={{ display: 'flex', alignItems: 'center', gap: '6px',
                      padding: '9px 18px', borderRadius: '8px', fontWeight: 600, fontSize: '0.85rem' }}>
                    <Eye size={15} /> View Full Details
                  </button>

                  {c.requiresAdminReview && c.status !== 'Cancelled' && (
                    <>
                      <button onClick={() => handleApprove(c.id)} className="btn-approve"
                        style={{ display: 'flex', alignItems: 'center', gap: '8px',
                          padding: '9px 20px', borderRadius: '8px', fontWeight: 700, fontSize: '0.85rem' }}>
                        <CheckCircle size={15} /> Approve & Publish
                      </button>
                      <button onClick={() => handleReject(c.id)} className="btn-reject"
                        style={{ display: 'flex', alignItems: 'center', gap: '8px',
                          padding: '9px 20px', borderRadius: '8px', fontWeight: 700, fontSize: '0.85rem' }}>
                        <XCircle size={15} /> Reject & Cancel
                      </button>
                    </>
                  )}

                  {!c.requiresAdminReview && (
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px',
                      color: '#059669', fontSize: '0.82rem', fontWeight: 600, marginLeft: 'auto' }}>
                      <ShieldCheck size={16} color="#10b981" />
                      Approved / Clean Listing
                    </div>
                  )}
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
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10, marginBottom: 20, flexWrap: 'wrap' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <Truck size={20} color="#8b5cf6" />
              <h3 style={{ margin: 0 }}>
                Delivery Plans ({deliveryPlans.length})
              </h3>
              <span style={{ padding: '2px 10px', borderRadius: 12, fontSize: '0.78rem',
                fontWeight: 700, background: '#ede9fe', color: '#6d28d9' }}>
                {deliveryPlans.filter(p => p.status === 'PendingApproval').length} pending
              </span>
            </div>
            <button
              onClick={() => {
                fetchLogisticsResources();
                setShowCreatePlan(true);
              }}
              className="btn-primary"
              style={{ display: 'flex', alignItems: 'center', gap: 6, margin: 0, padding: '9px 18px', fontSize: '0.85rem', borderRadius: 8, cursor: 'pointer' }}
            >
              <Plus size={16} /> Create Delivery Plan
            </button>
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

      {/* ── Modal: Create Delivery Plan ───────────────────────── */}
      {showCreatePlan && (
        <div style={{
          position: 'fixed', inset: 0, background: 'rgba(15, 23, 42, 0.65)',
          backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'center',
          justifyContent: 'center', zIndex: 1000, padding: 16,
        }}>
          <div style={{
            background: 'white', borderRadius: 14, width: '100%', maxWidth: 560,
            maxHeight: '90vh', overflowY: 'auto', padding: 24,
            boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.2)',
          }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 18 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <Truck color="#8b5cf6" size={24} />
                <h3 style={{ margin: 0, fontSize: '1.2rem', color: '#1e293b' }}>Create Delivery Plan</h3>
              </div>
              <button
                onClick={() => setShowCreatePlan(false)}
                style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#64748b' }}
              >
                <X size={20} />
              </button>
            </div>

            <form onSubmit={handleCreatePlanSubmit}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, marginBottom: 14 }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, color: '#475569', marginBottom: 4 }}>
                    Catch ID *
                  </label>
                  <input
                    type="number"
                    required
                    placeholder="e.g. 1"
                    value={createPlanData.catchId}
                    onChange={e => setCreatePlanData({ ...createPlanData, catchId: e.target.value })}
                    style={{ width: '100%', padding: '9px 12px', borderRadius: 8, border: '1px solid #cbd5e1', fontSize: '0.9rem' }}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, color: '#475569', marginBottom: 4 }}>
                    Vehicle *
                  </label>
                  <select
                    value={createPlanData.vehicleCode}
                    onChange={e => setCreatePlanData({ ...createPlanData, vehicleCode: e.target.value })}
                    style={{ width: '100%', padding: '9px 12px', borderRadius: 8, border: '1px solid #cbd5e1', fontSize: '0.9rem' }}
                  >
                    {resourcesVehicles.length > 0 ? (
                      resourcesVehicles.map((v: any) => (
                        <option key={v.vehicleCode} value={v.vehicleCode}>
                          {v.vehicleCode} - {v.capacityKg}kg ({v.status})
                        </option>
                      ))
                    ) : (
                      <>
                        <option value="V01">V01 - 500kg (Available)</option>
                        <option value="V02">V02 - 1000kg (Available)</option>
                        <option value="V03">V03 - 2500kg (Available)</option>
                      </>
                    )}
                  </select>
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, marginBottom: 14 }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, color: '#475569', marginBottom: 4 }}>
                    Driver *
                  </label>
                  <select
                    value={createPlanData.driverCode}
                    onChange={e => setCreatePlanData({ ...createPlanData, driverCode: e.target.value })}
                    style={{ width: '100%', padding: '9px 12px', borderRadius: 8, border: '1px solid #cbd5e1', fontSize: '0.9rem' }}
                  >
                    {resourcesDrivers.length > 0 ? (
                      resourcesDrivers.map((d: any) => (
                        <option key={d.driverCode} value={d.driverCode}>
                          {d.driverCode} - {d.fullName}
                        </option>
                      ))
                    ) : (
                      <>
                        <option value="D01">D01 - Sunil Perera</option>
                        <option value="D02">D02 - Kamal Silva</option>
                        <option value="D03">D03 - Nimal Fernando</option>
                      </>
                    )}
                  </select>
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, color: '#475569', marginBottom: 4 }}>
                    Cold Storage *
                  </label>
                  <select
                    value={createPlanData.coldStorageCode}
                    onChange={e => setCreatePlanData({ ...createPlanData, coldStorageCode: e.target.value })}
                    style={{ width: '100%', padding: '9px 12px', borderRadius: 8, border: '1px solid #cbd5e1', fontSize: '0.9rem' }}
                  >
                    {resourcesStorage.length > 0 ? (
                      resourcesStorage.map((s: any) => (
                        <option key={s.storageCode} value={s.storageCode}>
                          {s.storageCode} - {s.name} ({s.temperatureCelsius}°C)
                        </option>
                      ))
                    ) : (
                      <>
                        <option value="C01">C01 - Negombo Chiller (2°C)</option>
                        <option value="C02">C02 - Peliyagoda Cold Room (4°C)</option>
                      </>
                    )}
                  </select>
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, marginBottom: 14 }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, color: '#475569', marginBottom: 4 }}>
                    Pickup Location *
                  </label>
                  <input
                    type="text"
                    required
                    value={createPlanData.pickupLocation}
                    onChange={e => setCreatePlanData({ ...createPlanData, pickupLocation: e.target.value })}
                    style={{ width: '100%', padding: '9px 12px', borderRadius: 8, border: '1px solid #cbd5e1', fontSize: '0.9rem' }}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, color: '#475569', marginBottom: 4 }}>
                    Delivery Destination *
                  </label>
                  <input
                    type="text"
                    required
                    value={createPlanData.deliveryLocation}
                    onChange={e => setCreatePlanData({ ...createPlanData, deliveryLocation: e.target.value })}
                    style={{ width: '100%', padding: '9px 12px', borderRadius: 8, border: '1px solid #cbd5e1', fontSize: '0.9rem' }}
                  />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr 1fr', gap: 14, marginBottom: 14 }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, color: '#475569', marginBottom: 4 }}>
                    Route Name *
                  </label>
                  <input
                    type="text"
                    required
                    value={createPlanData.selectedRoute}
                    onChange={e => setCreatePlanData({ ...createPlanData, selectedRoute: e.target.value })}
                    style={{ width: '100%', padding: '9px 12px', borderRadius: 8, border: '1px solid #cbd5e1', fontSize: '0.9rem' }}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, color: '#475569', marginBottom: 4 }}>
                    Distance (km)
                  </label>
                  <input
                    type="number"
                    value={createPlanData.distanceKm}
                    onChange={e => setCreatePlanData({ ...createPlanData, distanceKm: e.target.value })}
                    style={{ width: '100%', padding: '9px 12px', borderRadius: 8, border: '1px solid #cbd5e1', fontSize: '0.9rem' }}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, color: '#475569', marginBottom: 4 }}>
                    Est. Time (min)
                  </label>
                  <input
                    type="number"
                    value={createPlanData.estimatedMinutes}
                    onChange={e => setCreatePlanData({ ...createPlanData, estimatedMinutes: e.target.value })}
                    style={{ width: '100%', padding: '9px 12px', borderRadius: 8, border: '1px solid #cbd5e1', fontSize: '0.9rem' }}
                  />
                </div>
              </div>

              <div style={{ marginBottom: 20 }}>
                <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, color: '#475569', marginBottom: 4 }}>
                  Weather / Transit Notes
                </label>
                <input
                  type="text"
                  value={createPlanData.weatherNote}
                  onChange={e => setCreatePlanData({ ...createPlanData, weatherNote: e.target.value })}
                  style={{ width: '100%', padding: '9px 12px', borderRadius: 8, border: '1px solid #cbd5e1', fontSize: '0.9rem' }}
                />
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10 }}>
                <button
                  type="button"
                  onClick={() => setShowCreatePlan(false)}
                  className="btn-outline"
                  style={{ padding: '9px 18px', fontSize: '0.9rem', cursor: 'pointer' }}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="btn-primary"
                  style={{ padding: '9px 24px', fontSize: '0.9rem', margin: 0, cursor: 'pointer' }}
                >
                  Submit Delivery Plan
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      <style>{`@keyframes spin { from{transform:rotate(0deg)} to{transform:rotate(360deg)} }`}</style>
    </div>
  );
};
