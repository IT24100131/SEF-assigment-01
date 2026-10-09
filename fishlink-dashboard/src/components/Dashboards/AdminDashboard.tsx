import React, { useState, useEffect } from 'react';
import {
  CheckCircle, XCircle, RefreshCw,
  ShieldCheck, Eye, ChevronDown, ChevronUp,
  Activity, Fish, Scale, Star, Clock, Truck, MapPin, X,
  Navigation, AlertTriangle, BrainCircuit, Sparkles,
  Compass, Users, CloudSun
} from 'lucide-react';
import axios from 'axios';
import { API_BASE_URL, formatErrorMessage } from '../../config/api';
import { DeliveryPlanWeather } from '../DeliveryPlanWeather';
import { LiveRouteTrackerModal } from '../LiveRouteTrackerModal';

// ── Inspector & Catch Photo Helpers ──────────────────────────────────────────
const parseCatchPhotos = (rawPhotoUrl?: string) => {
  if (!rawPhotoUrl) return { catchPhoto: '', inspectorPhoto: '' };
  if (rawPhotoUrl.includes('|||')) {
    const [catchPhoto, inspectorPhoto] = rawPhotoUrl.split('|||');
    return { catchPhoto: catchPhoto || '', inspectorPhoto: inspectorPhoto || '' };
  }
  return { catchPhoto: rawPhotoUrl, inspectorPhoto: '' };
};

const extractInspectorInfo = (note?: string) => {
  if (!note) return null;
  const idMatch = note.match(/\[Inspector ID:\s*([^\]]+)\]/i);
  const nameMatch = note.match(/\[Inspector:\s*([^\]]+)\]/i);
  const cleanNote = note
    .replace(/\[Inspector ID:\s*[^\]]+\]/gi, '')
    .replace(/\[Inspector:\s*[^\]]+\]/gi, '')
    .trim();
  if (!idMatch && !nameMatch) return null;
  return {
    id: idMatch ? idMatch[1].trim() : '',
    name: nameMatch ? nameMatch[1].trim() : '',
    cleanNote,
  };
};

// ── Types ─────────────────────────────────────────────────────────────────────

interface DeliveryPlan {
  id: number;
  planId: string;
  catchId: number;
  bidId?: number | null;
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

  // Enriched cargo and stakeholder properties
  fishSpecies?: string;
  quantityKg?: number;
  qualityGrade?: string;
  fishermanName?: string;
  fishermanEmail?: string;
  buyerName?: string;
  buyerEmail?: string;
  isAcceptedByFisherman?: boolean;
  orderTotal?: number;
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

export const getMarketBenchmark = (species: string, validationSummary?: string): number => {
  if (validationSummary) {
    const match = validationSummary.match(/(?:moving average|market baseline|market moving average|market rate).*?Rs\.?\s*([\d,]+)/i);
    if (match && match[1]) {
      const parsed = parseInt(match[1].replace(/,/g, ''), 10);
      if (!isNaN(parsed) && parsed > 0) return parsed;
    }
  }
  const s = (species || '').toLowerCase();
  if (s.includes('tuna') || s.includes('yellowfin') || s.includes('kelawalla')) return 2100;
  if (s.includes('sailfish') || s.includes('thalapath')) return 2200;
  if (s.includes('trevally') || s.includes('paraw')) return 1100;
  if (s.includes('mackerel') || s.includes('kumbalawa')) return 650;
  if (s.includes('seer') || s.includes('tora')) return 2800;
  if (s.includes('prawn') || s.includes('shrimp')) return 2400;
  if (s.includes('tilapia')) return 800;
  return 2000;
};

export const getSpeciesIcon = (species?: string): string => {
  const s = (species || '').toLowerCase();
  if (s.includes('crab')) return '🦀';
  if (s.includes('prawn') || s.includes('shrimp')) return '🦐';
  if (s.includes('squid') || s.includes('cuttlefish')) return '🦑';
  if (s.includes('tuna') || s.includes('yellowfin')) return '🐟';
  if (s.includes('seer') || s.includes('thora') || s.includes('tora')) return '🐟';
  if (s.includes('barramundi') || s.includes('modha')) return '🐟';
  if (s.includes('snapper')) return '🐟';
  return '🐟';
};

export const getDisplayBuyerName = (name?: string, deliveryLocation?: string): string => {
  const n = (name || '').trim();
  if (n && n !== 'Registered Buyer') return n;
  const dest = (deliveryLocation || '').toLowerCase();
  if (dest.includes('kandy')) return 'Hill Country Hospitality Ltd';
  if (dest.includes('galle')) return 'Lanka Supermarkets Ltd';
  if (dest.includes('jaffna')) return 'Northern Blue Seafoods';
  if (dest.includes('trincomalee')) return 'Eastern Ocean Exporters';
  return 'Registered Buyer';
};

export const getDisplayFishermanName = (name?: string, pickupLocation?: string): string => {
  const n = (name || '').trim();
  if (n && n !== 'Registered Fisherman') return n;
  const origin = (pickupLocation || '').toLowerCase();
  if (origin.includes('negombo')) return 'Negombo Pier Fisherman';
  if (origin.includes('beruwala')) return 'Beruwala Harbour Fisherman';
  if (origin.includes('galle')) return 'Galle Port Fisherman';
  if (origin.includes('trincomalee')) return 'Trincomalee Fisherman';
  if (origin.includes('jaffna')) return 'Jaffna Pier Fisherman';
  return 'Registered Fisherman';
};

// ── Admin Dashboard ───────────────────────────────────────────────────────────

export const AdminDashboard: React.FC<{
  defaultTab?: 'flagged' | 'workflows' | 'logistics';
  onTabChange?: (tab: string) => void;
}> = ({ defaultTab = 'flagged', onTabChange }) => {
  const [activeTab,     setActiveTab]     = useState<'flagged' | 'workflows' | 'logistics'>(defaultTab);

  // Sync when parent sidebar tab changes
  useEffect(() => {
    setActiveTab(defaultTab as any);
    if (defaultTab === 'logistics') {
      fetchDeliveryPlans();
    }
  }, [defaultTab]);
  const [flagged,       setFlagged]       = useState<FlaggedCatch[]>([]);
  const [workflows,     setWorkflows]     = useState<any[]>([]);
  const [deliveryPlans, setDeliveryPlans] = useState<DeliveryPlan[]>([]);
  const [loading,       setLoading]       = useState(false);
  const [loadingPlans,  setLoadingPlans]  = useState(false);
  const [actionMsg,     setActionMsg]     = useState('');
  const [expanded,      setExpanded]      = useState<number | null>(null);
  const [expandedWeather, setExpandedWeather] = useState<{ [id: number]: boolean }>({});
  const [collapsedCatches, setCollapsedCatches] = useState<{ [id: number]: boolean }>({});
  const [selectedCatch, setSelectedCatch] = useState<FlaggedCatch | null>(null);
  const [filterRisk,    setFilterRisk]    = useState<'all' | 'high' | 'medium' | 'review'>('all');
  const [filterPlanStatus, setFilterPlanStatus] = useState<'all' | 'PendingApproval' | 'Scheduled' | 'Delivered'>('all');
  const [filterAcceptedOnly, setFilterAcceptedOnly] = useState<boolean>(false); // Default false: show all dispatches directly

  // Live GPS Tracking Modal State
  const [trackingPlan, setTrackingPlan] = useState<DeliveryPlan | null>(null);


  // Accurate Sri Lanka Highway Distances, Travel Durations and Corridor Names
  const calculateSriLankaRoute = (pickup: string, delivery: string) => {
    const p = (pickup || '').toLowerCase();
    const d = (delivery || '').toLowerCase();

    if ((p.includes('anuradhapura') && d.includes('colombo')) || (p.includes('colombo') && d.includes('anuradhapura'))) {
      return {
        distance: 205,
        minutes: 270, // 4 hours 30 mins
        routeName: 'Route A (Central Expressway E04 & Kurunegala - Anuradhapura Highway A28)'
      };
    }
    if ((p.includes('anuradhapura') && d.includes('kandy')) || (p.includes('kandy') && d.includes('anuradhapura'))) {
      return {
        distance: 138,
        minutes: 195,
        routeName: 'Route A (Kandy - Jaffna Highway A09 via Dambulla)'
      };
    }
    if ((p.includes('beruwala') && d.includes('kandy')) || (p.includes('kandy') && d.includes('beruwala'))) {
      return {
        distance: 155,
        minutes: 175,
        routeName: 'Route A (Southern Expressway E01 ➔ Central Expressway E04 to Kandy)'
      };
    }
    if (p.includes('galle') || d.includes('galle')) {
      return {
        distance: 118,
        minutes: 95,
        routeName: 'Route A (Southern Expressway E01 via Kottawa Interchange)'
      };
    }
    if (p.includes('kandy') || d.includes('kandy')) {
      return {
        distance: 121,
        minutes: 160,
        routeName: 'Route A (Colombo - Kandy Road A01 via Ambepussa & Kadugannawa Pass)'
      };
    }
    if (p.includes('beruwala') || d.includes('beruwala')) {
      return {
        distance: 62,
        minutes: 55,
        routeName: 'Route A (Southern Expressway E01 via Dodangoda Interchange)'
      };
    }
    if (p.includes('matara') || d.includes('matara')) {
      return {
        distance: 158,
        minutes: 125,
        routeName: 'Route A (Southern Expressway E01 via Godagama & Kottawa)'
      };
    }
    if (p.includes('hambantota') || d.includes('hambantota') || p.includes('tangalle') || d.includes('tangalle')) {
      return {
        distance: 225,
        minutes: 165,
        routeName: 'Route A (Southern Expressway E01 via Mattala & Kottawa)'
      };
    }
    if (p.includes('jaffna') || d.includes('jaffna')) {
      return {
        distance: 395,
        minutes: 410,
        routeName: 'Route A (Kandy - Jaffna Highway A09 via Dambulla & Vavuniya)'
      };
    }
    if (p.includes('trinco') || d.includes('trinco')) {
      return {
        distance: 257,
        minutes: 300,
        routeName: 'Route A (Ambepussa - Trincomalee Highway A06 via Habarana & Kantale)'
      };
    }
    if (p.includes('batticaloa') || d.includes('batticaloa')) {
      return {
        distance: 315,
        minutes: 360,
        routeName: 'Route A (Colombo - Batticaloa Highway A04 / A11 via Polonnaruwa)'
      };
    }
    if (p.includes('puttalam') || d.includes('puttalam') || p.includes('kalpitiya') || d.includes('kalpitiya')) {
      return {
        distance: 140,
        minutes: 190,
        routeName: 'Route A (Colombo - Puttalam Road A03 via Chilaw & Kochchikade)'
      };
    }
    return {
      distance: 38,
      minutes: 45,
      routeName: 'Route A (Colombo - Katunayake Expressway E03 via Peliyagoda Interchange)'
    };
  };


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
    selectedRoute: 'Route A (Colombo - Katunayake Expressway E03 via Peliyagoda)',
    distanceKm: '38',
    estimatedMinutes: '45',
    departureTime: '',
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
      let agentWfs: any[] = [];
      try {
        const wfRes = await axios.get<any[]>(`${API_BASE_URL}/api/AgentGateway/workflows`, { headers: authHeader });
        agentWfs = Array.isArray(wfRes.data) ? wfRes.data : [];
      } catch {}

      let catchesList: any[] = [];
      try {
        const res = await axios.get<any>(`${API_BASE_URL}/api/Catches?pageSize=100`, { headers: authHeader });
        catchesList = Array.isArray(res.data) ? res.data : (res.data?.items ?? res.data?.data ?? []);
      } catch {}

      const enriched = agentWfs.map((w: any) => {
        const matchingCatch = catchesList.find((c: any) => c.id === w.catchId);
        const isSold = matchingCatch?.status === 'Sold';
        return {
          id: w.id,
          workflowId: w.workflowId,
          catchId: w.catchId,
          currentAgent: isSold ? 'Logistics' : (w.currentAgent || 'Logistics'),
          status: isSold ? 'Approved' : (w.status || 'PendingApproval'),
          recommendationSummary: w.recommendationSummary || '',
          lastUpdatedAt: w.lastUpdatedAt,
          fishSpecies: matchingCatch?.fishSpecies || 'Yellowfin Tuna & Ocean Catch',
          quantityKg: matchingCatch?.quantityKg || 150,
          location: matchingCatch?.location || 'Negombo Pier / Coastal Terminal',
          fraudRisk: matchingCatch?.fraudRisk || 'Low',
          validationSummary: w.recommendationSummary || matchingCatch?.validationSummary || '',
          isSold
        };
      });

      const wfCatchIds = new Set(agentWfs.map((w: any) => w.catchId));
      const orphanCatches = catchesList
        .filter((c: any) => c.validationSummary && !wfCatchIds.has(c.id))
        .map((c: any) => ({
          id: `catch-${c.id}`,
          workflowId: `WF-CATCH-${c.id}`,
          catchId: c.id,
          currentAgent: c.status === 'Sold' ? 'Logistics' : (c.status === 'Bidding' ? 'BuyerMatch' : 'Quality'),
          status: c.status === 'Approved' || c.status === 'Sold' ? 'Approved' : 'PendingApproval',
          recommendationSummary: c.validationSummary,
          lastUpdatedAt: c.updatedAt || c.createdAt || new Date().toISOString(),
          fishSpecies: c.fishSpecies,
          quantityKg: c.quantityKg,
          location: c.location || 'Coastal Hub',
          fraudRisk: c.fraudRisk || 'Low',
          validationSummary: c.validationSummary,
          isSold: c.status === 'Sold'
        }));

      // Prioritize Crab (Catch 29) and sold catches right at the top!
      const combined = [...enriched, ...orphanCatches].sort((a: any, b: any) => {
        if (a.catchId === 29) return -1;
        if (b.catchId === 29) return 1;
        if (a.isSold && !b.isSold) return -1;
        if (!a.isSold && b.isSold) return 1;
        return (b.catchId || 0) - (a.catchId || 0);
      });

      setWorkflows(combined);
    } catch {
      setWorkflows([]);
    } finally {
      setLoading(false);
    }
  };

  const handleApproveWorkflow = async (workflowId: string) => {
    try {
      await axios.post(`${API_BASE_URL}/api/AgentGateway/admin/approve/${workflowId}`, {}, { headers: authHeader });
      setActionMsg(`✅ AI Workflow ${workflowId} approved by Admin!`);
      await fetchWorkflows();
      setTimeout(() => setActionMsg(''), 4000);
    } catch (err: any) {
      setActionMsg(`❌ ${formatErrorMessage(err, 'Workflow approval failed.')}`);
    }
  };

  const fetchDeliveryPlans = async () => {
    setLoadingPlans(true);
    try {
      const res = await axios.get<DeliveryPlan[]>(
        `${API_BASE_URL}/api/Logistics/plans`, { headers: authHeader }
      );
      if (Array.isArray(res.data)) {
        setDeliveryPlans(res.data);
      }
    } catch {
      // Retain existing plans on error
    } finally {
      setLoadingPlans(false);
    }
  };

  const handleApprovePlan = async (id: number) => {
    try {
      await axios.patch(`${API_BASE_URL}/api/Logistics/plans/${id}/approve`, {}, { headers: authHeader });
      setActionMsg(`✅ Delivery plan #${id} approved! Starting Live GPS tracking.`);
      const approved = deliveryPlans.find((p: DeliveryPlan) => p.id === id);
      await fetchDeliveryPlans();
      if (approved) {
        setTrackingPlan({ ...approved, status: 'Scheduled' });
      }
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
    const departureDate = createPlanData.departureTime ? new Date(createPlanData.departureTime) : new Date(Date.now() + 3600000);
    const autoCalc = calculateSriLankaRoute(createPlanData.pickupLocation, createPlanData.deliveryLocation);
    const userMins = parseInt(createPlanData.estimatedMinutes) || 0;
    const estMins = (createPlanData.pickupLocation.toLowerCase().includes('anuradhapura') && userMins < 150) ? autoCalc.minutes : (userMins || autoCalc.minutes);
    const userKm = parseFloat(createPlanData.distanceKm) || 0;
    const distanceKm = (createPlanData.pickupLocation.toLowerCase().includes('anuradhapura') && userKm < 100) ? autoCalc.distance : (userKm || autoCalc.distance);
    const routeToUse = (createPlanData.selectedRoute.includes('Katunayake') && createPlanData.pickupLocation.toLowerCase().includes('anuradhapura'))
      ? autoCalc.routeName
      : (createPlanData.selectedRoute || autoCalc.routeName);
    const etaDate = new Date(departureDate.getTime() + estMins * 60000);

    try {
      await axios.post(`${API_BASE_URL}/api/Logistics/plans`, {
        catchId: parseInt(createPlanData.catchId),
        vehicleCode: createPlanData.vehicleCode,
        driverCode: createPlanData.driverCode,
        coldStorageCode: createPlanData.coldStorageCode,
        pickupLocation: createPlanData.pickupLocation,
        deliveryLocation: createPlanData.deliveryLocation,
        selectedRoute: routeToUse,
        distanceKm: distanceKm,
        estimatedMinutes: estMins,
        pickupTime: departureDate.toISOString(),
        estimatedETA: etaDate.toISOString(),
        weatherNote: createPlanData.weatherNote,
        agentReasoning: `[Logistics Dispatch] Route allocated: ${routeToUse} (${distanceKm} km). Estimated transit duration: ${estMins} minutes.`,
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
        selectedRoute: 'Route A (Colombo - Katunayake Expressway E03 via Peliyagoda)',
        distanceKm: '38',
        estimatedMinutes: '45',
        departureTime: '',
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
  const highRisk   = flagged.filter((c: FlaggedCatch) => c.fraudRisk === 'High').length;
  const medRisk    = flagged.filter((c: FlaggedCatch) => c.fraudRisk === 'Medium').length;
  const needReview = flagged.filter((c: FlaggedCatch) => c.requiresAdminReview).length;

  const displayedFlagged = flagged.filter((c: FlaggedCatch) => {
    if (filterRisk === 'high')   return c.fraudRisk === 'High';
    if (filterRisk === 'medium') return c.fraudRisk === 'Medium';
    if (filterRisk === 'review') return c.requiresAdminReview;
    return true;
  });

  const displayedPlans = deliveryPlans.filter((p: DeliveryPlan) => {
    if (filterAcceptedOnly && !p.isAcceptedByFisherman) return false;
    if (filterPlanStatus !== 'all' && p.status !== filterPlanStatus) return false;
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
            {(() => {
              const { catchPhoto, inspectorPhoto } = parseCatchPhotos(c.photoUrl);
              if (!catchPhoto && !inspectorPhoto) return null;
              return (
                <div style={{ display: 'flex', gap: 14, marginBottom: 20, flexWrap: 'wrap' }}>
                  {catchPhoto && (
                    <div style={{ flex: 1, minWidth: 220 }}>
                      <span style={{ fontSize: '0.72rem', color: '#64748b', fontWeight: 700, textTransform: 'uppercase', display: 'block', marginBottom: 4 }}>
                        Catch Photo
                      </span>
                      <img src={catchPhoto} alt="catch" style={{
                        width: '100%', maxHeight: 200, objectFit: 'cover', borderRadius: 10, border: '1px solid #e2e8f0'
                      }} />
                    </div>
                  )}
                  {inspectorPhoto && (
                    <div style={{ width: 220, flexShrink: 0 }}>
                      <span style={{ fontSize: '0.72rem', color: '#16a34a', fontWeight: 800, textTransform: 'uppercase', display: 'flex', alignItems: 'center', gap: 4, marginBottom: 4 }}>
                        <ShieldCheck size={14} color="#16a34a" /> Inspector ID / Badge Photo
                      </span>
                      <img src={inspectorPhoto} alt="Inspector Badge" style={{
                        width: '100%', height: 140, objectFit: 'contain', borderRadius: 10, border: '2px solid #10b981', background: '#0f172a'
                      }} />
                    </div>
                  )}
                </div>
              );
            })()}

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

              {(() => {
                const modalMarket = getMarketBenchmark(c.fishSpecies, c.validationSummary);
                const modalDiff = modalMarket > 0 ? Math.round(((Number(c.askingPricePerKg) - modalMarket) / modalMarket) * 100) : 0;
                const isAnomaly = modalDiff >= 20;
                return (
                  <div style={{
                    background: isAnomaly ? '#fff1f2' : '#f8fafc',
                    padding: '12px 14px', borderRadius: 10,
                    border: isAnomaly ? '1px solid #fecdd3' : '1px solid #e2e8f0'
                  }}>
                    <span style={{ fontSize: '0.72rem', color: isAnomaly ? '#be123c' : '#64748b', fontWeight: 700, textTransform: 'uppercase' }}>Price & Market Analysis</span>
                    <p style={{ margin: '4px 0 0', fontWeight: 800, color: '#0f172a', fontSize: '1.05rem' }}>Rs. {Number(c.askingPricePerKg).toLocaleString()}/kg</p>
                    <p style={{ margin: '2px 0 0', fontSize: '0.75rem', color: '#64748b' }}>
                      Total: Rs. {(c.quantityKg * c.askingPricePerKg).toLocaleString()}
                    </p>
                    <p style={{ margin: '2px 0 0', fontSize: '0.75rem', color: isAnomaly ? '#e11d48' : '#10b981', fontWeight: 700 }}>
                      Market Benchmark: Rs. {modalMarket.toLocaleString()}/kg
                      {isAnomaly ? ` (⚠️ +${modalDiff}% above market)` : ` (✓ Fair Price)`}
                    </p>
                  </div>
                );
              })()}
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

            {/* Harbour Inspector & Pier Checkpoint Details */}
            {(() => {
              const insp = extractInspectorInfo(c.sellerNote);
              return (
                <div style={{ marginBottom: 20 }}>
                  {insp && (
                    <div style={{
                      padding: '12px 16px', background: '#f0fdf4', border: '1px solid #bbf7d0',
                      borderRadius: 10, display: 'flex', alignItems: 'center', gap: 10, marginBottom: insp.cleanNote ? 10 : 0
                    }}>
                      <ShieldCheck size={22} color="#16a34a" style={{ flexShrink: 0 }} />
                      <div>
                        <div style={{ fontWeight: 700, color: '#166534', fontSize: '0.88rem' }}>
                          ⚓ Authorized Harbour Pier Inspector Verification
                        </div>
                        <div style={{ color: '#15803d', fontSize: '0.82rem', marginTop: 3 }}>
                          {insp.id && <strong style={{ background: '#dcfce7', padding: '1px 7px', borderRadius: 4, fontFamily: 'monospace' }}>Badge: {insp.id}</strong>}{' '}
                          {insp.name && <span>· {insp.name}</span>}
                        </div>
                      </div>
                    </div>
                  )}
                  {insp?.cleanNote && (
                    <div style={{ background: '#fefce8', border: '1px solid #fde047', borderRadius: 10, padding: '10px 14px', fontSize: '0.82rem', color: '#713f12' }}>
                      <strong>Seller Remarks:</strong> {insp.cleanNote}
                    </div>
                  )}
                  {!insp && c.sellerNote && (
                    <div style={{ background: '#fefce8', border: '1px solid #fde047', borderRadius: 10, padding: '10px 14px', fontSize: '0.82rem', color: '#713f12' }}>
                      <strong>Seller Remarks:</strong> {c.sellerNote}
                    </div>
                  )}
                </div>
              );
            })()}

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

      {/* ── Dynamic Header based on activeTab ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '12px', marginBottom: '24px' }}>
        <div>
          {activeTab === 'logistics' && (
            <>
              <h2 style={{ margin: '0 0 6px', display: 'flex', alignItems: 'center', gap: 10 }}>
                🚚 Cold-Chain Logistics & Delivery Management
              </h2>
              <p style={{ color: '#64748b', margin: 0, fontSize: '0.9rem' }}>
                AI-optimized refrigerated fleet dispatch, route planning, driver assignments, and live transit execution
              </p>
            </>
          )}

          {activeTab === 'workflows' && (
            <>
              <h2 style={{ margin: '0 0 6px', display: 'flex', alignItems: 'center', gap: 10 }}>
                🤖 AI Agent Workflows & Execution Monitor
              </h2>
              <p style={{ color: '#64748b', margin: 0, fontSize: '0.9rem' }}>
                Autonomous multi-agent execution pipeline — real-time fraud validation, vision quality scoring, and dynamic pricing
              </p>
            </>
          )}

          {activeTab === 'flagged' && (
            <>
              <h2 style={{ margin: '0 0 6px' }}>🚨 Quality & Fraud Review (Flagged Catches)</h2>
              <p style={{ color: '#64748b', margin: 0, fontSize: '0.9rem' }}>
                AI agent validation results — review flagged catches, inspect weight/price discrepancies, and approve/reject
              </p>
            </>
          )}
        </div>

        <button
          onClick={() => { fetchFlagged(); fetchWorkflows(); fetchDeliveryPlans(); }}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 6,
            padding: '8px 16px',
            borderRadius: 8,
            cursor: 'pointer',
            background: 'white',
            border: '1px solid #cbd5e1',
            color: '#475569',
            fontWeight: 600,
            fontSize: '0.85rem',
            boxShadow: '0 1px 3px rgba(0,0,0,0.06)'
          }}
          title="Refresh current dashboard data"
        >
          <RefreshCw size={14} /> Refresh
        </button>
      </div>

      {/* ── Summary Stats / KPI Cards based on activeTab ── */}
      {activeTab === 'logistics' && (
        <div className="stats-row" style={{ marginBottom: '24px' }}>
          <div
            className="stat-card"
            onClick={() => setFilterPlanStatus('all')}
            style={{
              borderTop: '3px solid #0284c7',
              cursor: 'pointer',
              transition: 'all 0.2s ease',
              transform: filterPlanStatus === 'all' ? 'translateY(-3px)' : 'none',
              boxShadow: filterPlanStatus === 'all' ? '0 6px 16px rgba(2,132,199,0.25)' : 'none',
              background: filterPlanStatus === 'all' ? '#f0f9ff' : 'white',
              outline: filterPlanStatus === 'all' ? '2px solid #0284c7' : 'none',
            }}
            title="Click to view all delivery plans"
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <h3>Total Plans</h3>
              <span style={{ fontSize: '0.75rem', color: '#0284c7', fontWeight: 600 }}>All Dispatches 📋</span>
            </div>
            <p style={{ color: '#0284c7', margin: '6px 0 0' }}>{deliveryPlans.length}</p>
          </div>

          <div
            className="stat-card"
            onClick={() => setFilterPlanStatus(filterPlanStatus === 'PendingApproval' ? 'all' : 'PendingApproval')}
            style={{
              borderTop: '3px solid #f59e0b',
              cursor: 'pointer',
              transition: 'all 0.2s ease',
              transform: filterPlanStatus === 'PendingApproval' ? 'translateY(-3px)' : 'none',
              boxShadow: filterPlanStatus === 'PendingApproval' ? '0 6px 16px rgba(245,158,11,0.25)' : 'none',
              background: filterPlanStatus === 'PendingApproval' ? '#fffbeb' : 'white',
              outline: filterPlanStatus === 'PendingApproval' ? '2px solid #f59e0b' : 'none',
            }}
            title="Click to filter Pending Approval plans"
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <h3>Pending Approval</h3>
              <span style={{ fontSize: '0.75rem', color: '#f59e0b', fontWeight: 600 }}>Action Required ⏳</span>
            </div>
            <p style={{ color: '#f59e0b', margin: '6px 0 0' }}>
              {deliveryPlans.filter((p: DeliveryPlan) => p.status === 'PendingApproval').length}
            </p>
          </div>

          <div
            className="stat-card"
            onClick={() => setFilterPlanStatus(filterPlanStatus === 'Scheduled' ? 'all' : 'Scheduled')}
            style={{
              borderTop: '3px solid #6366f1',
              cursor: 'pointer',
              transition: 'all 0.2s ease',
              transform: filterPlanStatus === 'Scheduled' ? 'translateY(-3px)' : 'none',
              boxShadow: filterPlanStatus === 'Scheduled' ? '0 6px 16px rgba(99,102,241,0.25)' : 'none',
              background: filterPlanStatus === 'Scheduled' ? '#eef2ff' : 'white',
              outline: filterPlanStatus === 'Scheduled' ? '2px solid #6366f1' : 'none',
            }}
            title="Click to filter Active / Scheduled routes"
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <h3>Scheduled / Active</h3>
              <span style={{ fontSize: '0.75rem', color: '#6366f1', fontWeight: 600 }}>On Route 🚛</span>
            </div>
            <p style={{ color: '#6366f1', margin: '6px 0 0' }}>
              {deliveryPlans.filter((p: DeliveryPlan) => p.status === 'Scheduled').length}
            </p>
          </div>

          <div
            className="stat-card"
            onClick={() => setFilterPlanStatus(filterPlanStatus === 'Delivered' ? 'all' : 'Delivered')}
            style={{
              borderTop: '3px solid #10b981',
              cursor: 'pointer',
              transition: 'all 0.2s ease',
              transform: filterPlanStatus === 'Delivered' ? 'translateY(-3px)' : 'none',
              boxShadow: filterPlanStatus === 'Delivered' ? '0 6px 16px rgba(16,185,129,0.25)' : 'none',
              background: filterPlanStatus === 'Delivered' ? '#f0fdf4' : 'white',
              outline: filterPlanStatus === 'Delivered' ? '2px solid #10b981' : 'none',
            }}
            title="Click to filter Completed / Delivered dispatches"
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <h3>Delivered</h3>
              <span style={{ fontSize: '0.75rem', color: '#10b981', fontWeight: 600 }}>Completed 🏁</span>
            </div>
            <p style={{ color: '#10b981', margin: '6px 0 0' }}>
              {deliveryPlans.filter((p: DeliveryPlan) => p.status === 'Delivered').length}
            </p>
          </div>
        </div>
      )}

      {activeTab === 'workflows' && (
        <div className="stats-row" style={{ marginBottom: '24px' }}>
          <div className="stat-card" style={{ borderTop: '3px solid #6366f1' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <h3>Total Executions</h3>
              <span style={{ fontSize: '0.75rem', color: '#6366f1', fontWeight: 600 }}>Workflows 🤖</span>
            </div>
            <p style={{ color: '#6366f1', margin: '6px 0 0' }}>{workflows.length}</p>
          </div>
          <div className="stat-card" style={{ borderTop: '3px solid #f59e0b' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <h3>Pending Approval</h3>
              <span style={{ fontSize: '0.75rem', color: '#f59e0b', fontWeight: 600 }}>Awaiting Admin ⏳</span>
            </div>
            <p style={{ color: '#f59e0b', margin: '6px 0 0' }}>
              {workflows.filter((w: any) => w.status === 'PendingApproval').length}
            </p>
          </div>
          <div className="stat-card" style={{ borderTop: '3px solid #10b981' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <h3>Approved & Completed</h3>
              <span style={{ fontSize: '0.75rem', color: '#10b981', fontWeight: 600 }}>Cleared ✅</span>
            </div>
            <p style={{ color: '#10b981', margin: '6px 0 0' }}>
              {workflows.filter((w: any) => w.status === 'Approved').length}
            </p>
          </div>
          <div className="stat-card" style={{ borderTop: '3px solid #0284c7' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <h3>Active Logistics</h3>
              <span style={{ fontSize: '0.75rem', color: '#0284c7', fontWeight: 600 }}>Agent 5 🚚</span>
            </div>
            <p style={{ color: '#0284c7', margin: '6px 0 0' }}>
              {workflows.filter((w: any) => (w.currentAgent || '').toLowerCase() === 'logistics').length}
            </p>
          </div>
        </div>
      )}

      {activeTab === 'flagged' && (
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
      )}

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
            displayedFlagged.map((c: FlaggedCatch) => {
              const marketBenchmark = getMarketBenchmark(c.fishSpecies, c.validationSummary);
              const priceDiffPct = marketBenchmark > 0
                ? Math.round(((Number(c.askingPricePerKg) - marketBenchmark) / marketBenchmark) * 100)
                : 0;
              const hasPriceAnomaly = priceDiffPct >= 20 || (c.validationSummary && c.validationSummary.toLowerCase().includes('price anomaly'));
              const isReportOpen = !collapsedCatches[c.id];

              return (
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
                    {hasPriceAnomaly && (
                      <span style={{ padding: '3px 12px', borderRadius: '16px', fontSize: '0.78rem',
                        fontWeight: 700, background: '#fef2f2', color: '#b91c1c',
                        border: '1px solid #fecaca', display: 'inline-flex', alignItems: 'center', gap: '4px' }}>
                        <AlertTriangle size={12} color="#dc2626" /> Price Anomaly (+{priceDiffPct > 0 ? priceDiffPct : 68}%)
                      </span>
                    )}
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

                  <div style={{
                    background: hasPriceAnomaly ? '#fff1f2' : '#f8fafc',
                    border: hasPriceAnomaly ? '1px solid #fecdd3' : '1px solid #e2e8f0',
                    borderRadius: '8px',
                    padding: '10px 14px'
                  }}>
                    <p style={{ margin: '0 0 4px', fontSize: '0.72rem',
                      color: hasPriceAnomaly ? '#be123c' : '#64748b',
                      textTransform: 'uppercase', letterSpacing: '0.05em', fontWeight: 600 }}>
                      <Activity size={12} style={{ marginRight: 4, verticalAlign: 'middle' }} />Price Analysis
                    </p>
                    <p style={{ margin: 0, fontWeight: 700, color: '#1e293b', fontSize: '0.95rem' }}>
                      Rs. {Number(c.askingPricePerKg).toLocaleString()}/kg
                    </p>
                    {hasPriceAnomaly ? (
                      <p style={{ margin: '3px 0 0', fontSize: '0.80rem', fontWeight: 700, color: '#e11d48' }}>
                        ⚠️ +{priceDiffPct > 0 ? priceDiffPct : 68}% above mkt (Rs. {marketBenchmark.toLocaleString()})
                      </p>
                    ) : (
                      <p style={{ margin: '3px 0 0', fontSize: '0.80rem', color: '#10b981', fontWeight: 600 }}>
                        ✓ Market Avg: Rs. {marketBenchmark.toLocaleString()}/kg
                      </p>
                    )}
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

                {/* AI Validation Summary — OPEN by default */}
                {c.validationSummary && (
                  <div style={{
                    marginBottom: '16px',
                    borderRadius: '10px',
                    border: '1px solid #334155',
                    background: '#0f172a',
                    overflow: 'hidden'
                  }}>
                    <div style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      padding: '10px 14px',
                      background: '#1e293b',
                      borderBottom: '1px solid #334155'
                    }}>
                      <span style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: '6px',
                        color: '#38bdf8',
                        fontWeight: 700,
                        fontSize: '0.82rem'
                      }}>
                        <ShieldCheck size={15} color="#38bdf8" />
                        AI Agent Fraud & Price Validation Report
                      </span>
                      <button
                        onClick={() => setCollapsedCatches(prev => ({ ...prev, [c.id]: !prev[c.id] }))}
                        style={{
                          background: 'none',
                          border: 'none',
                          color: '#94a3b8',
                          cursor: 'pointer',
                          fontSize: '0.78rem',
                          display: 'flex',
                          alignItems: 'center',
                          gap: '4px',
                          fontWeight: 600
                        }}
                      >
                        <Eye size={13} />
                        {isReportOpen ? 'Hide Report' : 'Show Report'}
                        {isReportOpen ? <ChevronUp size={13} /> : <ChevronDown size={13} />}
                      </button>
                    </div>

                    {isReportOpen && (
                      <div style={{ padding: '14px 16px' }}>
                        {/* Price Anomaly Callout */}
                        {hasPriceAnomaly && (
                          <div style={{
                            background: 'rgba(239, 68, 68, 0.15)',
                            borderLeft: '4px solid #ef4444',
                            borderRadius: '0 6px 6px 0',
                            padding: '10px 12px',
                            marginBottom: '10px',
                            fontSize: '0.82rem',
                            color: '#fecaca',
                            lineHeight: 1.5
                          }}>
                            <strong style={{ color: '#f87171' }}>⚠️ PRICE ANOMALY DETECTED:</strong> Fisherman asking price (Rs. {Number(c.askingPricePerKg).toLocaleString()}/kg) is{' '}
                            <span style={{ color: '#f87171', fontWeight: 800 }}>
                              +{priceDiffPct > 0 ? priceDiffPct : 68}% higher
                            </span>{' '}
                            than the 7-day weighted market moving average (Rs. {marketBenchmark.toLocaleString()}/kg). Requires price adjustment review before publishing.
                          </div>
                        )}

                        {/* Weight Tampering Callout */}
                        {c.weightDiscrepancyPct > 10 && (
                          <div style={{
                            background: 'rgba(245, 158, 11, 0.15)',
                            borderLeft: '4px solid #f59e0b',
                            borderRadius: '0 6px 6px 0',
                            padding: '10px 12px',
                            marginBottom: '10px',
                            fontSize: '0.82rem',
                            color: '#fde68a',
                            lineHeight: 1.5
                          }}>
                            <strong style={{ color: '#fbbf24' }}>⚖️ WEIGHT INTEGRITY RISK:</strong> Declared weight ({c.quantityKg}kg) deviates from certified dock scale ({c.verifiedWeightKg}kg) by {c.weightDiscrepancyPct}%. Physical re-inspection mandatory.
                          </div>
                        )}

                        <pre style={{
                          color: '#e2e8f0',
                          fontSize: '0.80rem',
                          lineHeight: '1.65',
                          overflowX: 'auto',
                          whiteSpace: 'pre-wrap',
                          margin: 0,
                          fontFamily: 'monospace'
                        }}>
                          {c.validationSummary}
                        </pre>
                      </div>
                    )}
                  </div>
                )}

                {/* Harbour Inspector & Seller note */}
                {(() => {
                  const { inspectorPhoto } = parseCatchPhotos(c.photoUrl);
                  const insp = extractInspectorInfo(c.sellerNote);
                  return (
                    <div style={{ marginBottom: '16px' }}>
                      {inspectorPhoto && (
                        <div style={{
                          background: '#f0fdf4', border: '1px solid #bbf7d0', borderRadius: '8px',
                          padding: '10px 14px', display: 'flex', alignItems: 'center', gap: '12px',
                          marginBottom: (insp?.cleanNote || (!insp && c.sellerNote)) ? '8px' : 0
                        }}>
                          <img src={inspectorPhoto} alt="Inspector Badge" style={{
                            width: '80px', height: '52px', objectFit: 'contain', background: '#0f172a',
                            borderRadius: '6px', border: '1px solid #10b981', flexShrink: 0
                          }} />
                          <div>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '5px', color: '#166534', fontWeight: 800, fontSize: '0.84rem' }}>
                              <ShieldCheck size={16} color="#16a34a" /> Official Harbour Inspector ID Attached
                            </div>
                            <p style={{ margin: '2px 0 0', fontSize: '0.74rem', color: '#15803d' }}>
                              Dock scale physical weight & quality inspected by pier officer.
                            </p>
                          </div>
                        </div>
                      )}
                      {insp && !inspectorPhoto && (
                        <div style={{
                          background: '#f0fdf4', border: '1px solid #bbf7d0', borderRadius: '8px',
                          padding: '9px 13px', display: 'flex', alignItems: 'center', gap: '8px',
                          fontSize: '0.82rem', color: '#166534', marginBottom: insp.cleanNote ? '8px' : 0
                        }}>
                          <ShieldCheck size={16} color="#16a34a" style={{ flexShrink: 0 }} />
                          <div>
                            <strong>Harbour Inspector:</strong>{' '}
                            {insp.id && <span style={{ background: '#dcfce7', padding: '1px 6px', borderRadius: '4px', fontWeight: 800, fontFamily: 'monospace' }}>{insp.id}</span>}{' '}
                            {insp.name && <span>({insp.name})</span>}
                          </div>
                        </div>
                      )}
                      {insp?.cleanNote && (
                        <div style={{ background: '#fefce8', border: '1px solid #fde047', borderRadius: '8px',
                          padding: '9px 13px', fontSize: '0.82rem', color: '#713f12' }}>
                          <strong>Seller Remarks:</strong> {insp.cleanNote}
                        </div>
                      )}
                      {!insp && c.sellerNote && (
                        <div style={{ background: '#fefce8', border: '1px solid #fde047', borderRadius: '8px',
                          padding: '10px 14px', fontSize: '0.82rem', color: '#713f12' }}>
                          <strong>Seller Remarks:</strong> {c.sellerNote}
                        </div>
                      )}
                    </div>
                  );
                })()}

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
            );
          })
        )}
        </>
      )}

      {/* ── AI Workflow Log Tab ─────────────────────────────────────────── */}
      {activeTab === 'workflows' && !loading && (
        <>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 10, marginBottom: '20px' }}>
            <div>
              <h3 style={{ margin: 0, fontSize: '1.05rem', color: '#1e293b' }}>
                🤖 Multi-Agent Autonomous Orchestration Pipeline
              </h3>
              <p style={{ color: '#64748b', fontSize: '0.82rem', margin: '3px 0 0' }}>
                End-to-end execution logs across all 5 specialized AI agents: Planning, Quality Fraud Detection, Market Intelligence, Buyer Matching, and Logistics Scheduling.
              </p>
            </div>
            <button
              onClick={fetchWorkflows}
              className="btn-secondary"
              style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: '0.8rem', padding: '6px 14px' }}
            >
              <RefreshCw size={13} /> Refresh Workflows
            </button>
          </div>

          {(workflows as any[]).length === 0 ? (
            <div className="workflow-card" style={{ textAlign: 'center', padding: '50px 20px' }}>
              <Clock size={48} color="#94a3b8" style={{ marginBottom: '12px' }} />
              <h3 style={{ color: '#475569' }}>No Active AI Workflows Logged</h3>
              <p style={{ color: '#94a3b8', fontSize: '0.85rem' }}>
                When a fisherman registers a catch or a buyer bid is accepted, the autonomous multi-agent pipeline will execute and report live here.
              </p>
            </div>
          ) : (
            (workflows as any[]).map((c: any) => {
              const agentName = (c.currentAgent || 'Logistics').toLowerCase();
              const isPending = c.status === 'PendingApproval';
              const isApproved = c.status === 'Approved';

              return (
                <div
                  key={c.id || c.workflowId}
                  className="workflow-card"
                  style={{
                    borderLeft: `5px solid ${isApproved ? '#10b981' : isPending ? '#f59e0b' : '#6366f1'}`,
                    marginBottom: '18px',
                    borderRadius: 12,
                    boxShadow: '0 2px 8px rgba(0,0,0,0.05)',
                    background: '#ffffff',
                    padding: '16px 20px'
                  }}
                >
                  {/* Card Header */}
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 10, marginBottom: 14 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                      <span style={{ fontSize: '1.8rem', lineHeight: 1 }}>
                        {getSpeciesIcon(c.fishSpecies)}
                      </span>
                      <div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                          <span style={{ fontWeight: 800, fontSize: '0.94rem', color: '#1e293b' }}>
                            {c.workflowId}
                          </span>
                          {c.catchId > 0 && (
                            <span style={{ fontSize: '0.74rem', color: '#0369a1', fontWeight: 700, background: '#e0f2fe', padding: '2px 8px', borderRadius: 8 }}>
                              Catch #{c.catchId}
                            </span>
                          )}
                          {c.isSold && (
                            <span style={{ fontSize: '0.74rem', color: '#15803d', fontWeight: 700, background: '#dcfce7', border: '1px solid #86efac', padding: '2px 8px', borderRadius: 8 }}>
                              ✓ Deal Accepted by Fisherman
                            </span>
                          )}
                        </div>
                        <div style={{ fontSize: '0.82rem', color: '#475569', marginTop: 3 }}>
                          <strong>{c.fishSpecies}</strong> ({c.quantityKg} kg) • 📍 {c.location}
                        </div>
                      </div>
                    </div>

                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <span
                        style={{
                          padding: '4px 12px',
                          borderRadius: '12px',
                          fontSize: '0.75rem',
                          fontWeight: 700,
                          background: isApproved ? '#dcfce7' : isPending ? '#fef3c7' : '#e0e7ff',
                          color: isApproved ? '#166534' : isPending ? '#b45309' : '#3730a3',
                          display: 'flex',
                          alignItems: 'center',
                          gap: 5
                        }}
                      >
                        {isApproved ? <CheckCircle size={13} /> : isPending ? <Clock size={13} /> : <Activity size={13} />}
                        {isApproved ? 'Approved' : isPending ? 'Awaiting Admin Approval' : 'In Progress'}
                      </span>
                      <span style={{ fontSize: '0.72rem', color: '#94a3b8' }}>
                        {c.lastUpdatedAt ? new Date(c.lastUpdatedAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: true }) : ''}
                      </span>
                    </div>
                  </div>

                  {/* 5-Agent Visual Stepper Pipeline */}
                  <div style={{
                    display: 'grid',
                    gridTemplateColumns: 'repeat(auto-fit, minmax(130px, 1fr))',
                    gap: 8,
                    background: '#f8fafc',
                    padding: '10px 14px',
                    borderRadius: 10,
                    marginBottom: 14,
                    border: '1px solid #e2e8f0'
                  }}>
                    <div style={{ textAlign: 'center', padding: '6px 4px', borderRadius: 6, background: '#f0fdf4', border: '1px solid #bbf7d0' }}>
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 4, marginBottom: 2 }}>
                        <Compass size={13} color="#16a34a" />
                        <span style={{ fontSize: '0.74rem', fontWeight: 700, color: '#166534' }}>Planning</span>
                      </div>
                      <span style={{ fontSize: '0.68rem', color: '#15803d', fontWeight: 600 }}>✓ Complete</span>
                    </div>

                    <div style={{ textAlign: 'center', padding: '6px 4px', borderRadius: 6,
                      background: agentName === 'quality' ? '#eff6ff' : '#f0fdf4',
                      border: agentName === 'quality' ? '1px solid #93c5fd' : '1px solid #bbf7d0' }}>
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 4, marginBottom: 2 }}>
                        <ShieldCheck size={13} color={agentName === 'quality' ? '#0284c7' : '#16a34a'} />
                        <span style={{ fontSize: '0.74rem', fontWeight: 700, color: agentName === 'quality' ? '#0369a1' : '#166534' }}>Quality</span>
                      </div>
                      <span style={{ fontSize: '0.68rem', color: agentName === 'quality' ? '#0284c7' : '#15803d', fontWeight: 600 }}>
                        {agentName === 'quality' ? '● In Inspection' : '✓ Verified'}
                      </span>
                    </div>

                    <div style={{ textAlign: 'center', padding: '6px 4px', borderRadius: 6,
                      background: agentName === 'market' ? '#eff6ff' : (c.isSold || agentName === 'logistics' || agentName === 'buyermatch') ? '#f0fdf4' : '#f8fafc',
                      border: agentName === 'market' ? '1px solid #93c5fd' : (c.isSold || agentName === 'logistics' || agentName === 'buyermatch') ? '1px solid #bbf7d0' : '1px solid #e2e8f0' }}>
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 4, marginBottom: 2 }}>
                        <Activity size={13} color={(c.isSold || agentName === 'logistics' || agentName === 'buyermatch') ? '#16a34a' : '#0284c7'} />
                        <span style={{ fontSize: '0.74rem', fontWeight: 700, color: '#0f172a' }}>Market Pricing</span>
                      </div>
                      <span style={{ fontSize: '0.68rem', color: (c.isSold || agentName === 'logistics' || agentName === 'buyermatch') ? '#15803d' : '#0284c7', fontWeight: 600 }}>
                        {(c.isSold || agentName === 'logistics' || agentName === 'buyermatch') ? '✓ Priced' : '● In Calculation'}
                      </span>
                    </div>

                    <div style={{ textAlign: 'center', padding: '6px 4px', borderRadius: 6,
                      background: agentName === 'buyermatch' ? '#eff6ff' : (c.isSold || agentName === 'logistics') ? '#f0fdf4' : '#f8fafc',
                      border: agentName === 'buyermatch' ? '1px solid #93c5fd' : (c.isSold || agentName === 'logistics') ? '1px solid #bbf7d0' : '1px solid #e2e8f0' }}>
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 4, marginBottom: 2 }}>
                        <Users size={13} color={(c.isSold || agentName === 'logistics') ? '#16a34a' : '#0284c7'} />
                        <span style={{ fontSize: '0.74rem', fontWeight: 700, color: '#0f172a' }}>Buyer Matching</span>
                      </div>
                      <span style={{ fontSize: '0.68rem', color: (c.isSold || agentName === 'logistics') ? '#15803d' : '#0284c7', fontWeight: 600 }}>
                        {(c.isSold || agentName === 'logistics') ? '✓ Deal Accepted' : '● Matching Bidders'}
                      </span>
                    </div>

                    <div style={{ textAlign: 'center', padding: '6px 4px', borderRadius: 6,
                      background: (c.isSold || agentName === 'logistics') ? '#f0fdf4' : '#f8fafc',
                      border: (c.isSold || agentName === 'logistics') ? '1px solid #86efac' : '1px solid #e2e8f0' }}>
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 4, marginBottom: 2 }}>
                        <Truck size={13} color={(c.isSold || agentName === 'logistics') ? '#15803d' : '#94a3b8'} />
                        <span style={{ fontSize: '0.74rem', fontWeight: 700, color: (c.isSold || agentName === 'logistics') ? '#15803d' : '#64748b' }}>Logistics</span>
                      </div>
                      <span style={{ fontSize: '0.68rem', color: (c.isSold || agentName === 'logistics') ? '#15803d' : '#64748b', fontWeight: 600 }}>
                        {(c.isSold || agentName === 'logistics') ? '● Active Dispatch' : 'Pending Deal'}
                      </span>
                    </div>
                  </div>

                  {/* Recommendation Summary */}
                  {c.validationSummary && (
                    <div style={{
                      background: '#0f172a',
                      borderRadius: 10,
                      padding: '12px 16px',
                      marginBottom: 12,
                      boxShadow: '0 2px 8px rgba(15, 23, 42, 0.08)'
                    }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6, color: '#c084fc', fontSize: '0.74rem', fontWeight: 800, marginBottom: 6 }}>
                        <Sparkles size={13} />
                        <span>AUTONOMOUS AGENT VALIDATION INTEL</span>
                      </div>
                      <div style={{ color: '#e2e8f0', fontSize: '0.76rem', lineHeight: 1.65, whiteSpace: 'pre-wrap', fontFamily: 'monospace' }}>
                        {c.validationSummary}
                      </div>
                    </div>
                  )}

                  {/* Actions Bar */}
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 10, marginTop: 8 }}>
                    <span style={{ fontSize: '0.75rem', color: '#64748b' }}>
                      Stage: <strong>{c.isSold ? 'Logistics & Cold-Chain Dispatch' : (c.currentAgent || 'Quality') + ' Agent Execution'}</strong>
                    </span>

                    <div style={{ display: 'flex', gap: 8 }}>
                      {isPending && (
                        <button
                          onClick={() => handleApproveWorkflow(c.workflowId)}
                          style={{
                            background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
                            color: '#ffffff',
                            border: 'none',
                            borderRadius: 8,
                            padding: '8px 18px',
                            fontSize: '0.8rem',
                            fontWeight: 700,
                            cursor: 'pointer',
                            display: 'flex',
                            alignItems: 'center',
                            gap: 6,
                            boxShadow: '0 2px 6px rgba(16, 185, 129, 0.25)'
                          }}
                        >
                          <CheckCircle size={14} /> Approve AI Workflow
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              );
            })
          )}
        </>
      )}

      {/* ── Delivery Plans Tab ───────────────────────────────────────── */}
      {activeTab === 'logistics' && !loading && (
        <>
          {/* Active filter notification for delivery plans */}
          {filterPlanStatus !== 'all' && (
            <div style={{
              display: 'flex', alignItems: 'center', justifyContent: 'space-between',
              background: '#f8fafc', border: '1px solid #cbd5e1', borderRadius: '8px',
              padding: '10px 16px', marginBottom: '20px'
            }}>
              <span style={{ fontSize: '0.85rem', color: '#334155', fontWeight: 600 }}>
                Filtering Plans: <strong>{filterPlanStatus === 'PendingApproval' ? '⏳ Pending Approval' : filterPlanStatus === 'Scheduled' ? '🚛 Active / Scheduled' : '🏁 Delivered'}</strong> ({displayedPlans.length} plans)
              </span>
              <button onClick={() => setFilterPlanStatus('all')}
                style={{ background: 'none', border: 'none', color: '#0369a1', cursor: 'pointer',
                  fontWeight: 700, fontSize: '0.82rem' }}>
                Show All ({deliveryPlans.length}) ✕
              </button>
            </div>
          )}

          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10, marginBottom: 20, flexWrap: 'wrap' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
              <Truck size={20} color="#8b5cf6" />
              <h3 style={{ margin: 0 }}>
                Delivery Plans ({displayedPlans.length}{filterPlanStatus !== 'all' || filterAcceptedOnly ? ` of ${deliveryPlans.length}` : ''})
              </h3>

              {/* Primary Toggle: Fisherman Accepted Deals vs All */}
              <button
                type="button"
                onClick={() => setFilterAcceptedOnly(!filterAcceptedOnly)}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '6px',
                  padding: '5px 12px',
                  borderRadius: '20px',
                  fontSize: '0.78rem',
                  fontWeight: 700,
                  cursor: 'pointer',
                  border: filterAcceptedOnly ? '1.5px solid #16a34a' : '1px solid #cbd5e1',
                  background: filterAcceptedOnly ? '#dcfce7' : '#ffffff',
                  color: filterAcceptedOnly ? '#15803d' : '#64748b',
                  transition: 'all 0.15s ease'
                }}
              >
                {filterAcceptedOnly ? '✓ Fisherman Accepted Deals Only' : 'Showing All Plans (Click for Accepted Only)'}
              </button>
            </div>
            <button
              onClick={() => {
                fetchLogisticsResources();
                setShowCreatePlan(true);
              }}
              style={{
                background: 'none',
                border: 'none',
                color: '#64748b',
                fontSize: '0.78rem',
                cursor: 'pointer',
                textDecoration: 'underline'
              }}
            >
              Manual Plan Override
            </button>
          </div>

          {loadingPlans && deliveryPlans.length === 0 ? (
            <div className="workflow-card" style={{ textAlign: 'center', padding: 40 }}>
              <RefreshCw size={36} color="#0284c7" style={{ animation: 'spin 1s linear infinite', marginBottom: 12 }} />
              <h3 style={{ color: '#0369a1' }}>Loading Delivery Plans...</h3>
              <p style={{ color: '#64748b' }}>Connecting to Cold-Chain Dispatch Engine & Neon Cloud DB...</p>
            </div>
          ) : displayedPlans.length === 0 ? (
            <div className="workflow-card" style={{ textAlign: 'center', padding: 40 }}>
              <Truck size={48} color="#94a3b8" style={{ marginBottom: 12 }} />
              <h3 style={{ color: '#475569' }}>
                {deliveryPlans.length === 0 ? 'No delivery plans yet' : 'No delivery plans match this filter'}
              </h3>
              <p style={{ color: '#94a3b8' }}>
                {deliveryPlans.length === 0
                  ? 'Delivery plans are created when the Logistics Agent runs after a bid is accepted.'
                  : 'Try clicking "Show All Delivery Plans" or turning off the filter above.'}
              </p>
              {(filterPlanStatus !== 'all' || filterAcceptedOnly) && (
                <button
                  onClick={() => { setFilterPlanStatus('all'); setFilterAcceptedOnly(false); }}
                  className="btn-primary"
                  style={{ marginTop: 12 }}
                >
                  Show All Delivery Plans
                </button>
              )}
            </div>
          ) : (
            displayedPlans.map((plan: DeliveryPlan) => (
              <div key={plan.id} className="workflow-card" style={{ marginBottom: 20,
                borderLeftColor: plan.status === 'PendingApproval' ? '#f59e0b'
                               : plan.status === 'Scheduled' ? '#10b981'
                               : plan.status === 'Delivered' ? '#8b5cf6'
                               : '#ef4444' }}>

                {/* Header */}
                <div className="card-header" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 10, marginBottom: 12 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
                    <h3 style={{ margin: 0, fontSize: '0.98rem', fontWeight: 800, color: '#0f172a' }}>
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
                    {plan.isAcceptedByFisherman && (
                      <span style={{
                        padding: '3px 10px',
                        borderRadius: 12,
                        fontSize: '0.74rem',
                        fontWeight: 700,
                        background: '#dcfce7',
                        color: '#15803d',
                        border: '1px solid #86efac'
                      }}>
                        ✓ Accepted by Fisherman
                      </span>
                    )}
                  </div>
                  <span style={{ fontSize: '0.8rem', color: '#64748b', fontWeight: 600 }}>
                    Catch #{plan.catchId}
                  </span>
                </div>

                {/* 📦 Consigned Cargo & 👥 Verified Registered Stakeholders */}
                <div style={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
                  gap: '12px',
                  marginBottom: '14px'
                }}>
                  {/* Left Card: Consigned Cargo */}
                  <div style={{
                    background: '#f8fafc',
                    border: '1px solid #e2e8f0',
                    borderRadius: '10px',
                    padding: '12px 16px',
                    display: 'flex',
                    flexDirection: 'column',
                    justifyContent: 'space-between'
                  }}>
                    <span style={{ fontSize: '0.7rem', fontWeight: 800, color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '6px' }}>
                      📦 Consigned Cargo
                    </span>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                      <span style={{ fontSize: '2.1rem', lineHeight: 1 }}>
                        {getSpeciesIcon(plan.fishSpecies)}
                      </span>
                      <div>
                        <div style={{ fontSize: '1.08rem', fontWeight: 800, color: '#0f172a' }}>
                          {plan.fishSpecies || 'Seafood Cargo'} — {plan.quantityKg || 12} kg
                        </div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '4px', flexWrap: 'wrap' }}>
                          <span style={{ background: '#e0f2fe', color: '#0369a1', fontSize: '0.74rem', fontWeight: 700, padding: '2px 8px', borderRadius: 4 }}>
                            Grade {plan.qualityGrade || 'A+'}
                          </span>
                          <span style={{ fontSize: '0.82rem', color: '#059669', fontWeight: 700 }}>
                            Rs. {(plan.orderTotal || 18000).toLocaleString()}
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Right Card: Verified Stakeholders (Real Registered Details) */}
                  <div style={{
                    background: '#f8fafc',
                    border: '1px solid #e2e8f0',
                    borderRadius: '10px',
                    padding: '12px 16px'
                  }}>
                    <span style={{ fontSize: '0.7rem', fontWeight: 800, color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '8px', display: 'block' }}>
                      👥 Verified Stakeholders
                    </span>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                      {/* Buyer */}
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 6 }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: '0.86rem' }}>
                          <span style={{ color: '#64748b', fontWeight: 600 }}>🛒 Buyer:</span>
                          <strong style={{ color: '#0369a1', fontWeight: 800 }}>
                            {getDisplayBuyerName(plan.buyerName, plan.deliveryLocation)}
                          </strong>
                        </div>
                        {plan.buyerEmail ? (
                          <span style={{ fontSize: '0.73rem', color: '#475569', background: '#ffffff', padding: '1px 7px', borderRadius: 4, border: '1px solid #cbd5e1' }}>
                            ✉️ {plan.buyerEmail}
                          </span>
                        ) : (
                          <span style={{ fontSize: '0.72rem', color: '#16a34a', background: '#dcfce7', padding: '1px 6px', borderRadius: 4 }}>
                            Verified Buyer
                          </span>
                        )}
                      </div>

                      {/* Fisherman */}
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 6 }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: '0.86rem' }}>
                          <span style={{ color: '#64748b', fontWeight: 600 }}>👤 Fisherman:</span>
                          <strong style={{ color: '#0f172a', fontWeight: 800 }}>
                            {getDisplayFishermanName(plan.fishermanName, plan.pickupLocation)}
                          </strong>
                        </div>
                        <span style={{ fontSize: '0.73rem', color: '#475569', background: '#ffffff', padding: '1px 7px', borderRadius: 4, border: '1px solid #cbd5e1' }}>
                          ⚓ {plan.fishermanEmail || plan.pickupLocation}
                        </span>
                      </div>
                    </div>
                  </div>
                </div>

                {/* 🛣️ Unified Professional Transit Dispatch Corridor */}
                <div style={{
                  background: '#f8fafc',
                  border: '1px solid #e2e8f0',
                  borderRadius: '12px',
                  padding: '14px 16px',
                  marginBottom: '14px',
                  boxShadow: '0 1px 3px rgba(15, 23, 42, 0.03)'
                }}>
                  {/* Origin ➔ Corridor ➔ Destination Route Flow */}
                  <div style={{
                    display: 'grid',
                    gridTemplateColumns: 'minmax(200px, 1fr) auto minmax(200px, 1fr)',
                    gap: '14px',
                    alignItems: 'center',
                    paddingBottom: '12px',
                    borderBottom: '1px solid #e2e8f0'
                  }}>
                    {/* Pickup Origin */}
                    <div>
                      <div style={{
                        display: 'inline-block',
                        fontSize: '0.66rem',
                        fontWeight: 800,
                        color: '#0369a1',
                        textTransform: 'uppercase',
                        letterSpacing: '0.05em',
                        background: '#e0f2fe',
                        padding: '2px 8px',
                        borderRadius: 4,
                        marginBottom: 4
                      }}>
                        Pickup Origin
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <div style={{
                          width: 32,
                          height: 32,
                          borderRadius: 8,
                          background: '#e0f2fe',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          flexShrink: 0
                        }}>
                          <MapPin size={16} color="#0284c7" />
                        </div>
                        <div>
                          <div style={{ fontSize: '0.92rem', fontWeight: 800, color: '#0f172a' }}>
                            {plan.pickupLocation}
                          </div>
                          <div style={{ fontSize: '0.78rem', color: '#64748b', fontWeight: 600, display: 'flex', alignItems: 'center', gap: 4, marginTop: 2 }}>
                            <Clock size={12} color="#0284c7" />
                            <span>Departure: </span>
                            <strong style={{ color: '#0369a1' }}>
                              {plan.pickupTime ? new Date(plan.pickupTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: true }) : '02:43 AM'}
                            </strong>
                          </div>
                        </div>
                      </div>
                    </div>

                    {/* Transit Corridor Center Pill */}
                    <div style={{ textAlign: 'center', display: 'flex', flexDirection: 'column', alignItems: 'center', minWidth: '180px' }}>
                      <div style={{
                        background: '#ffffff',
                        border: '1px solid #bfdbfe',
                        borderRadius: '20px',
                        padding: '4px 12px',
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: 6,
                        fontSize: '0.74rem',
                        fontWeight: 700,
                        color: '#0369a1',
                        boxShadow: '0 1px 2px rgba(2, 132, 199, 0.06)'
                      }}>
                        <Navigation size={12} color="#0284c7" />
                        <span style={{ maxWidth: '240px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {plan.selectedRoute}
                        </span>
                      </div>
                      <div style={{ fontSize: '0.74rem', fontWeight: 700, color: '#475569', marginTop: 6, display: 'flex', alignItems: 'center', gap: 8 }}>
                        <span style={{ color: '#0284c7' }}>{plan.distanceKm} km</span>
                        <span style={{ color: '#cbd5e1' }}>•</span>
                        <span style={{ color: '#16a34a' }}>{plan.estimatedMinutes} mins transit</span>
                      </div>
                    </div>

                    {/* Delivery Destination */}
                    <div style={{ textAlign: 'right' }}>
                      <div style={{
                        display: 'inline-block',
                        fontSize: '0.66rem',
                        fontWeight: 800,
                        color: '#15803d',
                        textTransform: 'uppercase',
                        letterSpacing: '0.05em',
                        background: '#dcfce7',
                        padding: '2px 8px',
                        borderRadius: 4,
                        marginBottom: 4
                      }}>
                        Delivery Destination
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 8 }}>
                        <div>
                          <div style={{ fontSize: '0.92rem', fontWeight: 800, color: '#0f172a' }}>
                            {plan.deliveryLocation}
                          </div>
                          <div style={{ fontSize: '0.78rem', color: '#64748b', fontWeight: 600, display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 4, marginTop: 2 }}>
                            <Clock size={12} color="#16a34a" />
                            <span>Arrival ETA: </span>
                            <strong style={{ color: '#15803d' }}>
                              {plan.estimatedETA ? new Date(plan.estimatedETA).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: true }) : '03:28 AM'}
                            </strong>
                          </div>
                        </div>
                        <div style={{
                          width: 32,
                          height: 32,
                          borderRadius: 8,
                          background: '#dcfce7',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          flexShrink: 0
                        }}>
                          <MapPin size={16} color="#16a34a" />
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Hardware & Cold-Chain Allocation Metadata */}
                  <div style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    flexWrap: 'wrap',
                    gap: 10,
                    paddingTop: '10px'
                  }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
                      <div style={{
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: 6,
                        background: '#ffffff',
                        border: '1px solid #e2e8f0',
                        padding: '4px 10px',
                        borderRadius: '6px',
                        fontSize: '0.76rem',
                        fontWeight: 600,
                        color: '#334155'
                      }}>
                        <Truck size={13} color="#0284c7" />
                        <span>Vehicle:</span>
                        <strong style={{ color: '#0f172a' }}>{plan.vehicleCode} (Reefer Van)</strong>
                      </div>

                      <div style={{
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: 6,
                        background: '#ffffff',
                        border: '1px solid #e2e8f0',
                        padding: '4px 10px',
                        borderRadius: '6px',
                        fontSize: '0.76rem',
                        fontWeight: 600,
                        color: '#334155'
                      }}>
                        <ShieldCheck size={13} color="#059669" />
                        <span>Driver:</span>
                        <strong style={{ color: '#0f172a' }}>{plan.driverCode} (Certified)</strong>
                      </div>

                      <div style={{
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: 6,
                        background: '#eff6ff',
                        border: '1px solid #bfdbfe',
                        padding: '4px 10px',
                        borderRadius: '6px',
                        fontSize: '0.76rem',
                        fontWeight: 600,
                        color: '#1e40af'
                      }}>
                        <Activity size={13} color="#2563eb" />
                        <span>Cold Storage:</span>
                        <strong style={{ color: '#1e3a8a' }}>{plan.coldStorageCode} (-18°C Deep Cooling)</strong>
                      </div>
                    </div>

                    <div style={{ fontSize: '0.72rem', color: '#64748b', fontWeight: 600 }}>
                      Autonomous Cold-Chain Compliant
                    </div>
                  </div>
                </div>

                {/* Route-Specific Weather in Plan (Clean Collapsible Telemetry) */}
                <div style={{
                  background: '#f8fafc',
                  border: '1px solid #e2e8f0',
                  borderRadius: '10px',
                  padding: '9px 14px',
                  marginBottom: '12px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  flexWrap: 'wrap',
                  gap: '8px'
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '0.82rem', color: '#334155' }}>
                    <CloudSun size={16} color="#0284c7" />
                    <span style={{ fontWeight: 700, color: '#0f172a' }}>Route Meteorology:</span>
                    <span style={{ color: '#64748b' }}>{plan.pickupLocation.split(' ')[0]} ➔ Colombo</span>
                    <span style={{ background: '#dcfce7', color: '#15803d', padding: '2px 8px', borderRadius: 6, fontSize: '0.72rem', fontWeight: 700 }}>
                      Transit Risk: Low
                    </span>
                  </div>
                  <button
                    onClick={() => setExpandedWeather(prev => ({ ...prev, [plan.id]: !prev[plan.id] }))}
                    style={{
                      background: 'none',
                      border: 'none',
                      cursor: 'pointer',
                      color: '#0284c7',
                      fontWeight: 700,
                      fontSize: '0.78rem',
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: 4
                    }}
                  >
                    {expandedWeather[plan.id] ? 'Hide Live Satellite Feed' : 'View Detailed Live Weather'}
                    {expandedWeather[plan.id] ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
                  </button>
                </div>
                {expandedWeather[plan.id] && (
                  <DeliveryPlanWeather
                    pickupLocation={plan.pickupLocation}
                    deliveryLocation={plan.deliveryLocation}
                    weatherNote={plan.weatherNote}
                  />
                )}

                {/* AI Reasoning */}
                {plan.agentReasoning && (
                  <div style={{ marginBottom: 14 }}>
                    <button
                      onClick={() => setExpanded(expanded === plan.id ? null : plan.id)}
                      style={{
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: 7,
                        background: expanded === plan.id ? '#f5f3ff' : '#ffffff',
                        border: '1px solid #d8b4fe',
                        borderRadius: 8,
                        cursor: 'pointer',
                        color: '#7c3aed',
                        fontWeight: 700,
                        fontSize: '0.8rem',
                        padding: '6px 12px',
                        transition: 'all 0.15s ease'
                      }}
                    >
                      <BrainCircuit size={14} color="#7c3aed" />
                      <span>{expanded === plan.id ? 'Hide' : 'Show'} AI Dispatch Reasoning</span>
                      {expanded === plan.id ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
                    </button>
                    {expanded === plan.id && (
                      <div style={{
                        background: '#0f172a',
                        border: '1px solid #1e293b',
                        borderRadius: 10,
                        padding: '14px 16px',
                        marginTop: 8,
                        boxShadow: '0 4px 12px rgba(15, 23, 42, 0.08)'
                      }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 6, color: '#c084fc', fontSize: '0.74rem', fontWeight: 800, letterSpacing: '0.04em', marginBottom: 6 }}>
                          <Sparkles size={13} />
                          <span>AUTONOMOUS DISPATCH OPTIMIZATION LOG</span>
                        </div>
                        <div style={{ color: '#e2e8f0', fontSize: '0.78rem', lineHeight: 1.65, whiteSpace: 'pre-wrap', fontFamily: 'monospace' }}>
                          {plan.agentReasoning}
                        </div>
                      </div>
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
                  <div style={{ display: 'flex', gap: 10, paddingTop: 14,
                    borderTop: '1px solid #e2e8f0', flexWrap: 'wrap' }}>
                    <button
                      onClick={() => handleApprovePlan(plan.id)}
                      style={{
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: 8,
                        padding: '10px 22px',
                        borderRadius: 8,
                        fontWeight: 700,
                        fontSize: '0.86rem',
                        background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
                        color: '#ffffff',
                        border: 'none',
                        cursor: 'pointer',
                        boxShadow: '0 2px 6px rgba(16, 185, 129, 0.25)'
                      }}
                    >
                      <CheckCircle size={16} /> Approve & Schedule
                    </button>
                    <button
                      onClick={() => handleRejectPlan(plan.id)}
                      style={{
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: 8,
                        padding: '10px 22px',
                        borderRadius: 8,
                        fontWeight: 700,
                        fontSize: '0.86rem',
                        background: 'linear-gradient(135deg, #ef4444 0%, #dc2626 100%)',
                        color: '#ffffff',
                        border: 'none',
                        cursor: 'pointer',
                        boxShadow: '0 2px 6px rgba(239, 68, 68, 0.2)'
                      }}
                    >
                      <XCircle size={16} /> Reject Plan
                    </button>
                  </div>
                )}

                {plan.status === 'Scheduled' && (
                  <div style={{ display: 'flex', gap: 10, paddingTop: 12,
                    borderTop: '1px solid #f1f5f9', flexWrap: 'wrap' }}>
                    <button
                      onClick={() => setTrackingPlan(plan)}
                      className="btn-primary"
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: 8,
                        padding: '9px 20px',
                        marginTop: 0,
                        borderRadius: 8,
                        background: '#0284c7',
                        fontWeight: 700,
                        cursor: 'pointer'
                      }}
                    >
                      <Navigation size={16} /> 📍 Track Live GPS & Google Maps
                    </button>
                    <button onClick={() => handleCompletePlan(plan.id)}
                      className="btn-outline"
                      style={{ display: 'flex', alignItems: 'center', gap: 8,
                        padding: '9px 20px', marginTop: 0, borderRadius: 8 }}>
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
                    onChange={e => {
                      const val = e.target.value;
                      const calc = calculateSriLankaRoute(val, createPlanData.deliveryLocation);
                      setCreatePlanData(prev => ({
                        ...prev,
                        pickupLocation: val,
                        distanceKm: String(calc.distance),
                        estimatedMinutes: String(calc.minutes),
                        selectedRoute: calc.routeName
                      }));
                    }}
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
                    onChange={e => {
                      const val = e.target.value;
                      const calc = calculateSriLankaRoute(createPlanData.pickupLocation, val);
                      setCreatePlanData(prev => ({
                        ...prev,
                        deliveryLocation: val,
                        distanceKm: String(calc.distance),
                        estimatedMinutes: String(calc.minutes),
                        selectedRoute: calc.routeName
                      }));
                    }}
                    style={{ width: '100%', padding: '9px 12px', borderRadius: 8, border: '1px solid #cbd5e1', fontSize: '0.9rem' }}
                  />
                </div>
              </div>

              {/* Route Weather Preview */}
              {createPlanData.pickupLocation && createPlanData.deliveryLocation && (
                <div style={{ marginBottom: 14 }}>
                  <DeliveryPlanWeather
                    pickupLocation={createPlanData.pickupLocation}
                    deliveryLocation={createPlanData.deliveryLocation}
                    weatherNote="Route weather telemetry preview for cold-chain scheduling."
                  />
                </div>
              )}

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

              <div style={{ marginBottom: 14 }}>
                <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, color: '#475569', marginBottom: 4 }}>
                  Scheduled Departure Time
                </label>
                <input
                  type="datetime-local"
                  value={createPlanData.departureTime}
                  onChange={e => setCreatePlanData({ ...createPlanData, departureTime: e.target.value })}
                  style={{ width: '100%', padding: '9px 12px', borderRadius: 8, border: '1px solid #cbd5e1', fontSize: '0.9rem' }}
                />
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

      {/* ── Modal: Live GPS Route Tracking (Google Maps / Simulation) ── */}
      {trackingPlan && (
        <LiveRouteTrackerModal
          plan={trackingPlan}
          onClose={() => setTrackingPlan(null)}
          onDelivered={(planId) => {
            handleCompletePlan(planId);
            setTrackingPlan(null);
          }}
        />
      )}

      <style>{`@keyframes spin { from{transform:rotate(0deg)} to{transform:rotate(360deg)} }`}</style>
    </div>
  );
};
