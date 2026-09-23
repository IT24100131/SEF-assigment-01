import React, { useState, useEffect, useRef } from 'react';
import { Camera, MapPin, CheckCircle, Edit, Trash2, X, Ban, Send, AlertCircle, Bot, Users, ChevronDown, ChevronUp, RefreshCw } from 'lucide-react';
import axios from 'axios';
import { API_BASE_URL } from '../../config/api';

// ── Types ─────────────────────────────────────────────────────────────────────

interface CatchRecord {
  id: number;
  fishermanId: number;
  fishSpecies: string;
  quantityKg: number;
  askingPricePerKg: number;
  location: string;
  status: string;
  photoUrl?: string;
  // Quality & fraud fields
  verifiedWeightKg?: number;
  declaredQualityGrade?: string;
  inspectionResult?: string;
  catchDateTime?: string;
  fraudRisk?: string;
  weightDiscrepancyPct?: number;
  validationSummary?: string;
  requiresAdminReview?: boolean;
  qualityScore?: number;
  sellerNote?: string;
}

interface BidRecord {
  id: number;
  bidPricePerKg: number;
  bidTime: string;
  status: string;
}

// ── Status config ─────────────────────────────────────────────────────────────

const STATUS_CONFIG: Record<string, { emoji: string; label: string; color: string; bg: string; border: string }> = {
  Draft:           { emoji: '🟡', label: 'Draft',            color: '#92400e', bg: '#fef3c7', border: '#f59e0b' },
  Published:       { emoji: '🟢', label: 'Published',        color: '#065f46', bg: '#d1fae5', border: '#10b981' },
  Bidding:         { emoji: '🔵', label: 'Bidding',          color: '#1e40af', bg: '#dbeafe', border: '#3b82f6' },
  PendingApproval: { emoji: '🟠', label: 'Pending Approval', color: '#9a3412', bg: '#ffedd5', border: '#f97316' },
  Sold:            { emoji: '🟣', label: 'Sold',             color: '#4c1d95', bg: '#ede9fe', border: '#8b5cf6' },
  Cancelled:       { emoji: '🔴', label: 'Cancelled',        color: '#991b1b', bg: '#fee2e2', border: '#ef4444' },
  Expired:         { emoji: '⚪', label: 'Expired',          color: '#374151', bg: '#f3f4f6', border: '#9ca3af' },
};

// Statuses where Edit is allowed
const EDITABLE = ['Draft', 'Published'];
// Statuses where Cancel is allowed
const CANCELLABLE = ['Draft', 'Published'];
// Statuses where Publish button shows
const PUBLISHABLE = ['Draft'];
// Statuses where Delete (full remove) is allowed
const DELETABLE = ['Draft'];

const getApiErrorMessage = (err: any, fallback: string) => {
  const data = err?.response?.data;
  if (typeof data === 'string') return data;
  if (data?.detail) return data.detail;
  if (data?.title) return data.title;
  return fallback;
};

const getCurrentUserId = () => {
  try {
    const token = localStorage.getItem('token') ?? '';
    const payload = JSON.parse(atob(token.split('.')[1]));
    return Number(payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'] ?? 0);
  } catch {
    return 0;
  }
};

const getStatusCfg = (status: string) =>
  STATUS_CONFIG[status] ?? { emoji: '⚫', label: status, color: '#334155', bg: '#f1f5f9', border: '#94a3b8' };

// ── Status Badge ──────────────────────────────────────────────────────────────

const StatusBadge: React.FC<{ status: string }> = ({ status }) => {
  const cfg = getStatusCfg(status);
  return (
    <span style={{
      padding: '4px 12px', borderRadius: '20px', fontSize: '0.78rem', fontWeight: 700,
      color: cfg.color, background: cfg.bg, border: `1px solid ${cfg.border}`,
      whiteSpace: 'nowrap', flexShrink: 0,
    }}>
      {cfg.emoji} {cfg.label}
    </span>
  );
};

// ── CatchForm ─────────────────────────────────────────────────────────────────

interface CatchFormProps {
  editId: number | null;
  initialSpecies: string;
  initialQuantity: string;
  initialPrice: string;
  initialLocation: string | null;
  initialVerifiedWeight?: string;
  initialQualityGrade?: string;
  initialInspectionResult?: string;
  initialCatchDateTime?: string;
  initialSellerNote?: string;
  onCancel: () => void;
  onSaved: () => void;
}

const CatchForm: React.FC<CatchFormProps> = ({
  editId, initialSpecies, initialQuantity, initialPrice, initialLocation,
  initialVerifiedWeight, initialQualityGrade, initialInspectionResult,
  initialCatchDateTime, initialSellerNote,
  onCancel, onSaved,
}) => {
  const [species,          setSpecies]          = useState(initialSpecies);
  const [quantity,         setQuantity]         = useState(initialQuantity);
  const [price,            setPrice]            = useState(initialPrice);
  const [location,         setLocation]         = useState<string | null>(initialLocation);
  const [verifiedWeight,   setVerifiedWeight]   = useState(initialVerifiedWeight ?? '');
  const [qualityGrade,     setQualityGrade]     = useState(initialQualityGrade ?? '');
  const [inspectionResult, setInspectionResult] = useState(initialInspectionResult ?? 'Pending');
  const [catchDateTime,    setCatchDateTime]    = useState(initialCatchDateTime ?? '');
  const [sellerNote,       setSellerNote]       = useState(initialSellerNote ?? '');
  const [photoBase64,      setPhotoBase64]      = useState('');
  const [photoPreview,     setPhotoPreview]     = useState('');
  const [submitted,        setSubmitted]        = useState(false);
  const [error,            setError]            = useState('');
  const fileInputRef = useRef<HTMLInputElement>(null);

  const getAuthHeader = () => ({ headers: { Authorization: `Bearer ${localStorage.getItem('token')}` } });

  const handlePhotoUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setPhotoPreview(URL.createObjectURL(file));
    const reader = new FileReader();
    reader.onloadend = () => setPhotoBase64(reader.result as string);
    reader.readAsDataURL(file);
  };

  const handleGetLocation = () => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (pos) => setLocation(`${pos.coords.latitude.toFixed(4)}, ${pos.coords.longitude.toFixed(4)}`),
        ()    => setLocation('Negombo Pier (Simulated)')
      );
    } else {
      setLocation('Negombo Pier (Simulated)');
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    try {
      const payload = {
        fishSpecies:          species,
        quantityKg:           Number(quantity),
        askingPricePerKg:     Number(price),
        location:             location || 'Pending Location',
        photoUrl:             photoBase64 || '',
        verifiedWeightKg:     verifiedWeight ? Number(verifiedWeight) : 0,
        declaredQualityGrade: qualityGrade,
        inspectionResult:     inspectionResult,
        catchDateTime:        catchDateTime || null,
        sellerNote:           sellerNote,
      };
      if (editId !== null) {
        await axios.put(`${API_BASE_URL}/api/Catches/${editId}`, payload, getAuthHeader());
      } else {
        await axios.post(`${API_BASE_URL}/api/Catches`, payload, getAuthHeader());
      }
      setSubmitted(true);
      setTimeout(() => onSaved(), 1800);
    } catch (err: any) {
      const msg = err.response?.data ?? 'Error saving catch.';
      setError(typeof msg === 'string' ? msg : JSON.stringify(msg));
    }
  };

  if (submitted) {
    return (
      <div className="workflow-card" style={{ textAlign: 'center', padding: '40px', borderLeftColor: '#10b981' }}>
        <CheckCircle color="#10b981" size={60} style={{ margin: '0 auto 20px' }} />
        <h3>{editId ? 'Catch Updated!' : 'Catch Saved as Draft!'}</h3>
        <p style={{ color: '#64748b' }}>
          {editId ? 'Your changes have been saved.' : 'Your catch is saved as Draft. Publish it when ready.'}
        </p>
      </div>
    );
  }

  return (
    <div className="workflow-card">
      {error && (
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', background: '#fee2e2',
          border: '1px solid #fca5a5', borderRadius: '8px', padding: '12px', marginBottom: '16px' }}>
          <AlertCircle color="#ef4444" size={18} />
          <p style={{ margin: 0, color: '#991b1b', fontSize: '0.9rem' }}>{error}</p>
        </div>
      )}
      <form onSubmit={handleSubmit} className="auth-form" style={{ maxWidth: '520px' }}>
        <div className="form-group">
          <label>Fish Species</label>
          <select required value={species} onChange={(e) => setSpecies(e.target.value)}>
            <option value="Tuna (Yellowfin)">Tuna (Yellowfin)</option>
            <option value="Skipjack">Skipjack</option>
            <option value="Trevally (Paraw)">Trevally (Paraw)</option>
            <option value="Mackerel">Mackerel</option>
          </select>
        </div>
        <div className="form-group">
          <label>Quantity (kg)</label>
          <input type="number" placeholder="e.g. 150" required value={quantity} onChange={(e) => setQuantity(e.target.value)} />
        </div>
        <div className="form-group">
          <label>Asking Price (Rs/kg)</label>
          <input type="number" placeholder="e.g. 1400" required value={price} onChange={(e) => setPrice(e.target.value)} />
        </div>

        {/* ── Quality & Inspection Fields ── */}
        <div style={{ background: '#f0f9ff', border: '1px solid #bae6fd', borderRadius: '10px',
          padding: '16px', marginTop: '4px' }}>
          <p style={{ margin: '0 0 14px', fontWeight: 700, color: '#0369a1', fontSize: '0.88rem',
            display: 'flex', alignItems: 'center', gap: '6px' }}>
            🔍 Quality & Inspection Details
          </p>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
            <div className="form-group" style={{ margin: 0 }}>
              <label>Verified Weight (kg)</label>
              <input type="number" placeholder="e.g. 98" value={verifiedWeight}
                onChange={e => setVerifiedWeight(e.target.value)} />
              <p style={{ margin: '3px 0 0', fontSize: '0.72rem', color: '#64748b' }}>
                Physical weight at pier
              </p>
            </div>

            <div className="form-group" style={{ margin: 0 }}>
              <label>Declared Quality Grade</label>
              <select value={qualityGrade} onChange={e => setQualityGrade(e.target.value)}>
                <option value="">Select grade</option>
                <option value="A+">A+ (Premium)</option>
                <option value="A">A (Good)</option>
                <option value="B">B (Average)</option>
                <option value="C">C (Below avg)</option>
              </select>
            </div>

            <div className="form-group" style={{ margin: 0 }}>
              <label>Inspection Result</label>
              <select value={inspectionResult} onChange={e => setInspectionResult(e.target.value)}>
                <option value="Pending">Pending</option>
                <option value="Passed">✅ Passed</option>
                <option value="Failed">❌ Failed</option>
              </select>
            </div>

            <div className="form-group" style={{ margin: 0 }}>
              <label>Catch Date & Time</label>
              <input type="datetime-local" value={catchDateTime}
                onChange={e => setCatchDateTime(e.target.value)} />
            </div>
          </div>

          <div className="form-group" style={{ margin: '12px 0 0' }}>
            <label>Seller Note (optional)</label>
            <input type="text" placeholder="e.g. Fresh morning catch, iced immediately"
              value={sellerNote} onChange={e => setSellerNote(e.target.value)} />
          </div>
        </div>

        {/* Photo */}
        <div className="form-group">
          <label>Catch Photo</label>
          <input type="file" accept="image/*" ref={fileInputRef} style={{ display: 'none' }} onChange={handlePhotoUpload} />
          <button type="button" onClick={() => fileInputRef.current?.click()}
            className={photoBase64 ? 'btn-primary' : 'btn-outline'}
            style={{ display: 'flex', alignItems: 'center', gap: '8px', width: 'fit-content' }}>
            {photoBase64 ? <CheckCircle size={18} /> : <Camera size={18} />}
            {photoBase64 ? 'Photo Attached ✓' : 'Upload Photo'}
          </button>
          {photoPreview && (
            <div style={{ marginTop: '12px', position: 'relative', display: 'inline-block' }}>
              <img src={photoPreview} alt="Preview"
                style={{ width: '200px', height: '140px', objectFit: 'cover', borderRadius: '8px', border: '2px solid #10b981' }} />
              <button type="button" onClick={() => { setPhotoBase64(''); setPhotoPreview(''); }}
                style={{ position: 'absolute', top: '-8px', right: '-8px', background: '#ef4444', border: 'none',
                  borderRadius: '50%', width: '24px', height: '24px', cursor: 'pointer',
                  display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'white' }}>
                <X size={14} />
              </button>
            </div>
          )}
        </div>

        {/* GPS */}
        <div className="form-group">
          <label>GPS Location</label>
          <button type="button" onClick={handleGetLocation}
            className={location ? 'btn-primary' : 'btn-outline'}
            style={{ display: 'flex', alignItems: 'center', gap: '8px', width: 'fit-content' }}>
            {location ? <CheckCircle size={18} /> : <MapPin size={18} />}
            {location ?? 'Get GPS Location'}
          </button>
        </div>

        <button type="submit" className="btn-primary" style={{ marginTop: '20px', width: '100%' }}>
          {editId ? '💾 Save Changes' : '📋 Save as Draft'}
        </button>
      </form>
    </div>
  );
};

// ── Highest Bid display ───────────────────────────────────────────────────────

const HighestBid: React.FC<{ catchId: number }> = ({ catchId }) => {
  const [highestBid, setHighestBid] = useState<number | null>(null);

  useEffect(() => {
    const headers = { Authorization: `Bearer ${localStorage.getItem('token')}` };
    axios.get<BidRecord[]>(`${API_BASE_URL}/api/Bids/catch/${catchId}`, { headers })
      .then(res => {
        if (res.data.length > 0) {
          const max = Math.max(...res.data.map(b => b.bidPricePerKg));
          setHighestBid(max);
        }
      })
      .catch(() => {});
  }, [catchId]);

  if (highestBid === null) return null;
  return (
    <p style={{ margin: '6px 0 0', color: '#059669', fontWeight: 700, fontSize: '0.9rem' }}>
      🏆 Current highest bid: <strong>Rs. {highestBid.toLocaleString()}/kg</strong>
    </p>
  );
};

// ── Buyer Match Panel (shown on Published/Bidding cards) ─────────────────────

interface BuyerMatch {
  id: number;
  fishSpecies: string;
  quantityKg: number;
  askingPricePerKg: number;
  location: string;
  fishermanName: string;
  matchScore: number;
  matchReasons: string;
  qualityGrade: string;
}

const matchColor = (s: number) => s >= 80 ? '#059669' : s >= 60 ? '#d97706' : '#6b7280';
const matchBg    = (s: number) => s >= 80 ? '#d1fae5' : s >= 60 ? '#fef3c7' : '#f3f4f6';

const BuyerMatchPanel: React.FC<{ c: CatchRecord }> = ({ c }) => {
  const [open,          setOpen]          = useState(false);
  const [loading,       setLoading]       = useState(false);
  const [matches,       setMatches]       = useState<BuyerMatch[]>([]);
  const [fetched,       setFetched]       = useState(false);
  const [error,         setError]         = useState('');
  const [selectedBuyer, setSelectedBuyer] = useState<{ id: number; name: string } | null>(null);

  const fetchMatches = async () => {
    setLoading(true);
    setError('');
    try {
      const headers = { Authorization: `Bearer ${localStorage.getItem('token')}` };

      // Use the new preference-based scoring endpoint
      const res = await axios.get<{
        catchId: number;
        totalBuyers: number;
        scoredBuyers: {
          id: number; name: string; email: string;
          matchScore: number; matchReasons: string;
          hasPreference: boolean; totalBids: number;
          preferredSpecies: string; maxBudget: number; preferredCity: string;
        }[]
      }>(`${API_BASE_URL}/api/BuyerMatch/score-buyers/${c.id}`, { headers });

      setMatches(res.data.scoredBuyers as any);
      setFetched(true);
    } catch {
      setError('Could not reach matching service. Make sure the API is running.');
    } finally {
      setLoading(false);
    }
  };

  const handleToggle = () => {
    if (!open && !fetched) fetchMatches();
    setOpen(o => !o);
  };

  // Only show for Published or Bidding catches
  if (!['Published', 'Bidding'].includes(c.status)) return null;

  return (
    <>
    {/* Buyer Profile Modal */}
      {selectedBuyer && (
        <BuyerProfileModal
          buyerId={selectedBuyer.id}
          buyerName={selectedBuyer.name}
          onClose={() => setSelectedBuyer(null)}
        />
      )}
    <div style={{ marginTop: '14px', border: '1px solid #e0f2fe', borderRadius: '8px', overflow: 'hidden' }}>
      {/* Toggle header */}
      <button
        onClick={handleToggle}
        style={{
          width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          padding: '10px 14px', background: '#f0f9ff', border: 'none', cursor: 'pointer',
          fontSize: '0.85rem', fontWeight: 600, color: '#0369a1',
        }}
      >
        <span style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <Bot size={16} /> 🤖 AI Buyer Matching
          {fetched && !loading && (
            <span style={{ background: matches.length > 0 ? '#dbeafe' : '#fee2e2',
              color: matches.length > 0 ? '#1e40af' : '#991b1b',
              padding: '1px 8px', borderRadius: '10px', fontSize: '0.75rem', fontWeight: 700 }}>
              {matches.length} match{matches.length !== 1 ? 'es' : ''}
            </span>
          )}
        </span>
        <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
          {fetched && !loading && (
            <RefreshCw size={13} onClick={e => { e.stopPropagation(); setFetched(false); fetchMatches(); }}
              style={{ opacity: 0.6 }} />
          )}
          {open ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
        </span>
      </button>

      {/* Panel body */}
      {open && (
        <div style={{ padding: '14px', background: 'white' }}>
          {loading && (
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#64748b', fontSize: '0.85rem' }}>
              <RefreshCw size={15} style={{ animation: 'spin 1s linear infinite' }} />
              Running AI buyer matching algorithm…
            </div>
          )}

          {error && (
            <div style={{ display: 'flex', gap: '8px', background: '#fee2e2', borderRadius: '6px',
              padding: '10px', fontSize: '0.82rem', color: '#991b1b' }}>
              <AlertCircle size={15} style={{ flexShrink: 0 }} /> {error}
            </div>
          )}

          {!loading && !error && fetched && matches.length === 0 && (
            <div style={{ textAlign: 'center', padding: '16px', color: '#94a3b8', fontSize: '0.85rem' }}>
              <Users size={28} style={{ marginBottom: '6px', opacity: 0.4 }} />
              <p style={{ margin: 0 }}>No buyer matches found yet for this listing.</p>
            </div>
          )}

          {!loading && matches.length > 0 && (
            <div>
              <p style={{ margin: '0 0 12px', fontSize: '0.8rem', color: '#64748b' }}>
                Top {matches.length} registered buyer{matches.length !== 1 ? 's' : ''} — click to view profile:
              </p>
              {matches.map((m: any, i) => (
                <div key={m.id}
                  onClick={() => setSelectedBuyer({ id: m.id, name: m.name })}
                  style={{
                    display: 'flex', alignItems: 'center', gap: '12px',
                    padding: '10px 12px', marginBottom: '8px',
                    background: i === 0 ? '#f0fdf4' : '#f8fafc',
                    borderRadius: '8px',
                    border: `1px solid ${i === 0 ? '#bbf7d0' : '#e2e8f0'}`,
                    cursor: 'pointer', transition: 'box-shadow 0.15s',
                  }}
                  onMouseEnter={e => (e.currentTarget.style.boxShadow = '0 2px 8px rgba(0,0,0,0.1)')}
                  onMouseLeave={e => (e.currentTarget.style.boxShadow = 'none')}
                >
                  {/* Avatar with initial */}
                  <div style={{ width: '36px', height: '36px', borderRadius: '50%', flexShrink: 0,
                    background: i === 0 ? '#10b981' : i === 1 ? '#3b82f6' : '#94a3b8',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    color: 'white', fontWeight: 800, fontSize: '0.9rem' }}>
                    {m.name?.charAt(0).toUpperCase()}
                  </div>

                  {/* Info */}
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '2px' }}>
                      <p style={{ margin: 0, fontWeight: 600, fontSize: '0.85rem', color: '#1e293b' }}>
                        {m.name}
                      </p>
                      {/* Preference badge */}
                      {m.hasPreference ? (
                        <span style={{ padding: '1px 6px', borderRadius: '8px', fontSize: '0.68rem',
                          fontWeight: 700, background: '#dbeafe', color: '#1e40af' }}>
                          ⚙ Prefs set
                        </span>
                      ) : (
                        <span style={{ padding: '1px 6px', borderRadius: '8px', fontSize: '0.68rem',
                          fontWeight: 700, background: '#f3f4f6', color: '#9ca3af' }}>
                          No prefs
                        </span>
                      )}
                      {m.totalBids > 0 && (
                        <span style={{ padding: '1px 6px', borderRadius: '8px', fontSize: '0.68rem',
                          fontWeight: 700, background: '#d1fae5', color: '#059669' }}>
                          {m.totalBids} bid{m.totalBids !== 1 ? 's' : ''}
                        </span>
                      )}
                    </div>
                    {/* Preference summary */}
                    {m.hasPreference && (
                      <p style={{ margin: '0 0 2px', fontSize: '0.73rem', color: '#0369a1' }}>
                        Wants: {m.preferredSpecies || 'Any'} ·
                        Budget: Rs.{Number(m.maxBudget).toLocaleString()}/kg
                        {m.preferredCity ? ` · ${m.preferredCity}` : ''}
                      </p>
                    )}
                    <p style={{ margin: 0, fontSize: '0.72rem', color: '#64748b',
                      overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {m.matchReasons}
                    </p>
                  </div>

                  {/* Score + hint */}
                  <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 4, flexShrink: 0 }}>
                    <span style={{
                      padding: '3px 10px', borderRadius: '12px', fontSize: '0.78rem', fontWeight: 800,
                      background: matchBg(m.matchScore), color: matchColor(m.matchScore),
                    }}>
                      {m.matchScore}%
                    </span>
                    <span style={{ fontSize: '0.68rem', color: '#94a3b8' }}>View →</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
      <style>{`@keyframes spin { from{transform:rotate(0deg)} to{transform:rotate(360deg)} }`}</style>
    </div>
    </>
  );
};

// ── Buyer Profile Modal ───────────────────────────────────────────────────────

interface BuyerProfile {
  id: number;
  fullName: string;
  email: string;
  joinedAt: string;
  totalBids: number;
  acceptedBids: number;
  pendingBids: number;
  bidHistory: {
    id: number;
    bidPricePerKg: number;
    bidTime: string;
    status: string;
    species: string;
    quantity: number;
    location: string;
  }[];
}

const BuyerProfileModal: React.FC<{ buyerId: number; buyerName: string; onClose: () => void }> = ({ buyerId, buyerName, onClose }) => {
  const [profile, setProfile] = useState<BuyerProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [error,   setError]   = useState('');

  useEffect(() => {
    const headers = { Authorization: `Bearer ${localStorage.getItem('token')}` };

    const load = async () => {
      try {
        // If buyerId looks wrong (it may be catch ID), find real buyer ID by name first
        let realId = buyerId;

        // Always look up from buyers list to get correct ID
        const buyersRes = await axios.get<{ id: number; fullName: string }[]>(
          `${API_BASE_URL}/api/BuyerMatch/buyers`, { headers }
        );
        const found = buyersRes.data.find(
          b => b.fullName.toLowerCase() === buyerName.toLowerCase()
        );
        if (found) realId = found.id;

        const res = await axios.get<BuyerProfile>(
          `${API_BASE_URL}/api/BuyerMatch/buyers/${realId}`, { headers }
        );
        setProfile(res.data);
      } catch {
        setError('Could not load buyer profile.');
      } finally {
        setLoading(false);
      }
    };

    load();
  }, [buyerId, buyerName]);

  const statusColor = (s: string) =>
    s === 'Accepted' ? '#059669' : s === 'Pending' ? '#d97706' : '#ef4444';
  const statusBg = (s: string) =>
    s === 'Accepted' ? '#d1fae5' : s === 'Pending' ? '#fef3c7' : '#fee2e2';

  return (
    <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.55)',
      zIndex: 9999, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 20 }}>
      <div style={{ background: 'white', borderRadius: 14, width: '100%', maxWidth: 520,
        maxHeight: '85vh', display: 'flex', flexDirection: 'column',
        boxShadow: '0 24px 48px rgba(0,0,0,0.25)' }}>

        {/* Header */}
        <div style={{ padding: '20px 24px 16px', borderBottom: '1px solid #f1f5f9',
          display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 44, height: 44, borderRadius: '50%', background: '#dbeafe',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: '1.2rem', fontWeight: 800, color: '#1e40af' }}>
              {buyerName.charAt(0).toUpperCase()}
            </div>
            <div>
              <h3 style={{ margin: 0, fontSize: '1rem', color: '#1e293b' }}>{buyerName}</h3>
              <p style={{ margin: 0, fontSize: '0.78rem', color: '#64748b' }}>Buyer Profile</p>
            </div>
          </div>
          <button onClick={onClose}
            style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#64748b', padding: 4 }}>
            <X size={22} />
          </button>
        </div>

        {/* Body */}
        <div style={{ flex: 1, overflowY: 'auto', padding: '20px 24px' }}>
          {loading && (
            <div style={{ textAlign: 'center', padding: 40, color: '#94a3b8' }}>
              <RefreshCw size={28} style={{ animation: 'spin 1s linear infinite', marginBottom: 8 }} />
              <p style={{ margin: 0 }}>Loading profile…</p>
            </div>
          )}

          {error && (
            <div style={{ display: 'flex', gap: 8, background: '#fee2e2', borderRadius: 8,
              padding: 12, color: '#991b1b', fontSize: '0.85rem' }}>
              <AlertCircle size={16} style={{ flexShrink: 0 }} /> {error}
            </div>
          )}

          {profile && (
            <>
              {/* Stats row */}
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 10, marginBottom: 20 }}>
                {[
                  { label: 'Total Bids',    value: profile.totalBids,    color: '#005b96' },
                  { label: 'Accepted',      value: profile.acceptedBids, color: '#059669' },
                  { label: 'Pending',       value: profile.pendingBids,  color: '#d97706' },
                ].map(s => (
                  <div key={s.label} style={{ background: '#f8fafc', borderRadius: 10,
                    padding: '12px 10px', textAlign: 'center' }}>
                    <p style={{ margin: '0 0 4px', fontSize: '1.4rem', fontWeight: 800, color: s.color }}>
                      {s.value}
                    </p>
                    <p style={{ margin: 0, fontSize: '0.72rem', color: '#64748b', fontWeight: 600 }}>
                      {s.label}
                    </p>
                  </div>
                ))}
              </div>

              {/* Info */}
              <div style={{ background: '#f0f9ff', borderRadius: 8, padding: '12px 14px', marginBottom: 20 }}>
                <p style={{ margin: '0 0 4px', fontSize: '0.83rem', color: '#334155' }}>
                  📧 <strong>Email:</strong> {profile.email}
                </p>
                <p style={{ margin: 0, fontSize: '0.83rem', color: '#334155' }}>
                  📅 <strong>Member since:</strong> {new Date(profile.joinedAt).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })}
                </p>
              </div>

              {/* Bid history */}
              <h4 style={{ margin: '0 0 12px', color: '#334155', fontSize: '0.9rem' }}>
                Bid History ({profile.bidHistory.length})
              </h4>
              {profile.bidHistory.length === 0 ? (
                <p style={{ color: '#94a3b8', fontSize: '0.85rem', textAlign: 'center', padding: '16px 0' }}>
                  No bids placed yet.
                </p>
              ) : (
                profile.bidHistory.map(b => (
                  <div key={b.id} style={{ display: 'flex', justifyContent: 'space-between',
                    alignItems: 'center', padding: '10px 12px', marginBottom: 8,
                    background: '#f8fafc', borderRadius: 8, gap: 10 }}>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <p style={{ margin: '0 0 2px', fontWeight: 600, fontSize: '0.85rem', color: '#1e293b' }}>
                        {b.species} · {b.quantity}kg
                      </p>
                      <p style={{ margin: 0, fontSize: '0.75rem', color: '#64748b' }}>
                        Rs. {Number(b.bidPricePerKg).toLocaleString()}/kg ·{' '}
                        {new Date(b.bidTime).toLocaleDateString()}
                      </p>
                    </div>
                    <span style={{ padding: '3px 10px', borderRadius: 10, fontSize: '0.75rem',
                      fontWeight: 700, background: statusBg(b.status), color: statusColor(b.status),
                      flexShrink: 0 }}>
                      {b.status}
                    </span>
                  </div>
                ))
              )}
            </>
          )}
        </div>

        {/* Footer */}
        <div style={{ padding: '14px 24px', borderTop: '1px solid #f1f5f9' }}>
          <button onClick={onClose} className="btn-outline" style={{ width: '100%' }}>
            Close
          </button>
        </div>
      </div>
    </div>
  );
};

export const FishermanDashboard = () => {
  const [showForm,    setShowForm]    = useState(false);
  const [editTarget,  setEditTarget]  = useState<CatchRecord | null>(null);
  const [catches,     setCatches]     = useState<CatchRecord[]>([]);
  const [actionError, setActionError] = useState<string>('');

  const getAuthHeader = () => ({ headers: { Authorization: `Bearer ${localStorage.getItem('token')}` } });

  const fetchCatches = async () => {
    try {
      const res = await axios.get(`${API_BASE_URL}/api/Catches`, getAuthHeader());
      // API now returns PagedResult<Catch> — extract items
      const data = res.data;
      const items = Array.isArray(data) ? data : (data.items ?? []);
      const currentUserId = getCurrentUserId();
      setCatches(items.filter((item: CatchRecord) => item.fishermanId === currentUserId));
    } catch (err) {
      console.error('Failed to fetch catches', err);
    }
  };

  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { fetchCatches(); }, []);

  const handleEdit = (c: CatchRecord) => {
    if (!EDITABLE.includes(c.status)) {
      setActionError(`Cannot edit a "${c.status}" listing. Only Draft or Published listings can be edited.`);
      return;
    }
    setActionError('');
    setEditTarget(c);
    setShowForm(true);
  };

  const handlePublish = async (c: CatchRecord) => {
    if (!window.confirm(`Publish "${c.fishSpecies} (${c.quantityKg}kg)" listing? The AI Quality Agent will validate it.`)) return;
    try {
      await axios.patch(`${API_BASE_URL}/api/Catches/${c.id}/publish`, {}, getAuthHeader());
      await fetchCatches();
      setActionError('');

      // 🤖 Trigger AI Quality Validation Agent via ASP.NET Core proxy (mandatory backend rule)
      const workflowId = `workflow-${c.id}-${Date.now()}`;
      let fishermanId = 0;
      try {
        const token = localStorage.getItem('token') ?? '';
        const payload = JSON.parse(atob(token.split('.')[1]));
        fishermanId = Number(payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'] ?? 0);
      } catch { fishermanId = 0; }

      try {
        // Route through ASP.NET Core — NOT directly to port 8000
        await axios.post(`${API_BASE_URL}/api/AgentGateway/workflow/start`, {
          workflowId,
          catchId:               c.id,
          fishermanId,
          quantityKg:            Number(c.quantityKg),
          askingPrice:           Number(c.askingPricePerKg),
          fishSpecies:           c.fishSpecies,
          verifiedWeightKg:      Number(c.verifiedWeightKg ?? 0),
          declaredQualityGrade:  c.declaredQualityGrade ?? '',
          inspectionResult:      c.inspectionResult ?? 'Pending',
          catchDatetime:         c.catchDateTime ?? null,
          sellerNote:            c.sellerNote ?? '',
        }, getAuthHeader());
        setActionError('');
        setTimeout(() => fetchCatches(), 6000);
      } catch {
        console.warn('AI agent offline — validation skipped');
      }
    } catch (err: any) {
      setActionError(getApiErrorMessage(err, 'Error publishing listing.'));
    }
  };

  const handleCancel = async (c: CatchRecord) => {
    if (!CANCELLABLE.includes(c.status)) {
      setActionError(`Cannot cancel a "${c.status}" listing.`);
      return;
    }
    if (!window.confirm(`Cancel the listing for "${c.fishSpecies} (${c.quantityKg}kg)"? This cannot be undone.`)) return;
    try {
      await axios.patch(`${API_BASE_URL}/api/Catches/${c.id}/cancel`, {}, getAuthHeader());
      await fetchCatches();
      setActionError('');
    } catch (err: any) {
      setActionError(getApiErrorMessage(err, 'Error cancelling listing.'));
    }
  };

  const handleDelete = async (c: CatchRecord) => {
    if (!DELETABLE.includes(c.status)) {
      setActionError(`Cannot delete a "${c.status}" listing. Use Cancel instead.`);
      return;
    }
    if (!window.confirm(`Permanently delete the Draft listing for "${c.fishSpecies}"?`)) return;
    try {
      await axios.delete(`${API_BASE_URL}/api/Catches/${c.id}`, getAuthHeader());
      await fetchCatches();
      setActionError('');
    } catch (err: any) {
      setActionError(getApiErrorMessage(err, 'Error deleting listing.'));
    }
  };

  const handleFormSaved = async () => {
    await fetchCatches();
    setShowForm(false);
    setEditTarget(null);
  };

  const handleFormCancel = () => {
    setShowForm(false);
    setEditTarget(null);
  };

  // ── Stats ──────────────────────────────────────────────────────────────────
  const totalRevenue  = catches.filter(c => c.status === 'Sold')
    .reduce((acc, c) => acc + Number(c.quantityKg) * Number(c.askingPricePerKg), 0);
  const activeCount   = catches.filter(c => ['Published', 'Bidding'].includes(c.status)).length;
  const biddingCount  = catches.filter(c => c.status === 'Bidding').length;

  // ── Form view ──────────────────────────────────────────────────────────────
  if (showForm) {
    return (
      <div className="dashboard-content">
        <h2>{editTarget ? 'Edit Catch' : 'Register New Catch'}</h2>
        <button type="button" className="btn-outline" onClick={handleFormCancel} style={{ marginBottom: '20px' }}>
          ← Back to Dashboard
        </button>
        <CatchForm
          key={editTarget ? `edit-${editTarget.id}` : 'new'}
          editId={editTarget?.id ?? null}
          initialSpecies={editTarget?.fishSpecies ?? 'Tuna (Yellowfin)'}
          initialQuantity={editTarget?.quantityKg?.toString() ?? ''}
          initialPrice={editTarget?.askingPricePerKg?.toString() ?? ''}
          initialLocation={editTarget?.location ?? null}
          initialVerifiedWeight={editTarget?.verifiedWeightKg?.toString() ?? ''}
          initialQualityGrade={editTarget?.declaredQualityGrade ?? ''}
          initialInspectionResult={editTarget?.inspectionResult ?? 'Pending'}
          initialCatchDateTime={editTarget?.catchDateTime?.slice(0, 16) ?? ''}
          initialSellerNote={editTarget?.sellerNote ?? ''}
          onCancel={handleFormCancel}
          onSaved={handleFormSaved}
        />
      </div>
    );
  }

  // ── Main view ──────────────────────────────────────────────────────────────
  return (
    <div className="dashboard-content">
      <h2>My Catch Listings</h2>

      {/* Stats */}
      <div className="stats-row">
        <div className="stat-card">
          <h3>Total Listings</h3>
          <p>{catches.length}</p>
        </div>
        <div className="stat-card">
          <h3>Active (Published + Bidding)</h3>
          <p>{activeCount}</p>
        </div>
        <div className="stat-card">
          <h3>Bidding Now</h3>
          <p style={{ color: '#3b82f6' }}>{biddingCount}</p>
        </div>
        <div className="stat-card">
          <h3>Total Revenue (Sold)</h3>
          <p>Rs. {totalRevenue.toLocaleString()}</p>
        </div>
      </div>

      {/* Register button */}
      <button className="btn-primary"
        onClick={() => { setEditTarget(null); setShowForm(true); setActionError(''); }}
        style={{ marginTop: '30px', padding: '14px 28px', fontSize: '1rem' }}>
        + Register New Catch
      </button>

      {/* Action error */}
      {actionError && (
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', background: '#fee2e2',
          border: '1px solid #fca5a5', borderRadius: '8px', padding: '12px', marginTop: '16px' }}>
          <AlertCircle color="#ef4444" size={18} />
          <p style={{ margin: 0, color: '#991b1b', fontSize: '0.9rem' }}>{actionError}</p>
          <button onClick={() => setActionError('')}
            style={{ marginLeft: 'auto', background: 'none', border: 'none', cursor: 'pointer', color: '#991b1b' }}>
            <X size={16} />
          </button>
        </div>
      )}

      <h3 style={{ marginTop: '36px', color: '#334155' }}>My Recent Catches</h3>

      {catches.length === 0 ? (
        <p style={{ color: '#64748b' }}>No catches registered yet.</p>
      ) : (
        catches.map((c) => {
          const cfg       = getStatusCfg(c.status);
          const canEdit   = EDITABLE.includes(c.status);
          const canPublish = PUBLISHABLE.includes(c.status);
          const canCancel = CANCELLABLE.includes(c.status);
          const canDelete = DELETABLE.includes(c.status);
          const isLocked  = !canEdit;

          return (
            <div key={c.id} className="workflow-card"
              style={{ borderLeftColor: cfg.border, opacity: c.status === 'Cancelled' || c.status === 'Expired' ? 0.7 : 1 }}>

              {/* Card Header */}
              <div className="card-header">
                <h3 style={{ margin: 0 }}>{c.fishSpecies} ({c.quantityKg}kg)</h3>
                <StatusBadge status={c.status} />
              </div>

              {/* Photo */}
              {c.photoUrl && (
                <div style={{ marginBottom: '12px', background: '#f8fafc', borderRadius: '8px', overflow: 'hidden' }}>
                  <img src={c.photoUrl} alt="Catch"
                    style={{ width: '100%', maxHeight: '280px', objectFit: 'contain',
                      objectPosition: 'left center', display: 'block', borderRadius: '8px' }} />
                </div>
              )}

              {/* Body */}
              <div className="card-body">
                <p><strong>Asking Price:</strong> Rs. {c.askingPricePerKg}/kg</p>
                <p><strong>Location:</strong> {c.location}</p>

                {/* Quality & fraud validation results */}
                {c.fraudRisk && c.fraudRisk !== 'Unassessed' && (
                  <div style={{
                    marginTop: '10px', padding: '10px 14px', borderRadius: '8px',
                    background: c.fraudRisk === 'High' ? '#fee2e2'
                               : c.fraudRisk === 'Medium' ? '#fef3c7' : '#d1fae5',
                    border: `1px solid ${c.fraudRisk === 'High' ? '#fca5a5'
                               : c.fraudRisk === 'Medium' ? '#fde68a' : '#6ee7b7'}`,
                  }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between',
                      alignItems: 'center', flexWrap: 'wrap', gap: '8px' }}>
                      <span style={{ fontWeight: 700, fontSize: '0.82rem',
                        color: c.fraudRisk === 'High' ? '#991b1b'
                               : c.fraudRisk === 'Medium' ? '#92400e' : '#065f46' }}>
                        {c.fraudRisk === 'High' ? '🚨' : c.fraudRisk === 'Medium' ? '⚠️' : '✅'}
                        {' '}Fraud Risk: {c.fraudRisk}
                        {c.requiresAdminReview && ' — Admin Review Required'}
                      </span>
                      {c.qualityScore !== undefined && c.qualityScore > 0 && (
                        <span style={{ fontSize: '0.78rem', color: '#475569' }}>
                          Quality Score: <strong>{c.qualityScore}/100</strong>
                        </span>
                      )}
                    </div>
                    {c.weightDiscrepancyPct !== undefined && c.weightDiscrepancyPct > 0 && (
                      <p style={{ margin: '4px 0 0', fontSize: '0.78rem', color: '#64748b' }}>
                        Weight discrepancy: {c.weightDiscrepancyPct}%
                        {c.verifiedWeightKg ? ` (Verified: ${c.verifiedWeightKg}kg)` : ''}
                      </p>
                    )}
                  </div>
                )}

                {/* Highest bid — only show for Bidding status */}
                {c.status === 'Bidding' && <HighestBid catchId={c.id} />}

                {/* Locked notice */}
                {isLocked && c.status !== 'Cancelled' && c.status !== 'Expired' && (
                  <p style={{ margin: '8px 0 0', color: '#64748b', fontSize: '0.82rem',
                    display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <AlertCircle size={14} /> This listing is locked for editing ({c.status}).
                  </p>
                )}
              </div>

              {/* Actions */}
              <div className="card-actions" style={{
                borderTop: '1px solid #f1f5f9', paddingTop: '14px',
                marginTop: '14px', justifyContent: 'flex-start', gap: '10px', flexWrap: 'wrap',
              }}>
                {/* Publish — only for Draft */}
                {canPublish && (
                  <button className="btn-primary" onClick={() => handlePublish(c)}
                    style={{ display: 'flex', alignItems: 'center', gap: '6px',
                      padding: '8px 16px', fontSize: '0.85rem', marginTop: 0 }}>
                    <Send size={15} /> Publish Listing
                  </button>
                )}

                {/* Edit — only Draft/Published */}
                {canEdit && (
                  <button className="btn-outline" onClick={() => handleEdit(c)}
                    style={{ display: 'flex', alignItems: 'center', gap: '6px',
                      padding: '8px 14px', color: '#3b82f6', borderColor: '#3b82f6', fontSize: '0.85rem' }}>
                    <Edit size={15} /> Edit
                  </button>
                )}

                {/* Cancel — Draft/Published */}
                {canCancel && (
                  <button className="btn-outline" onClick={() => handleCancel(c)}
                    style={{ display: 'flex', alignItems: 'center', gap: '6px',
                      padding: '8px 14px', color: '#f97316', borderColor: '#f97316', fontSize: '0.85rem' }}>
                    <Ban size={15} /> Cancel Listing
                  </button>
                )}

                {/* Delete — Draft only (full remove) */}
                {canDelete && (
                  <button className="btn-outline" onClick={() => handleDelete(c)}
                    style={{ display: 'flex', alignItems: 'center', gap: '6px',
                      padding: '8px 14px', color: '#ef4444', borderColor: '#ef4444', fontSize: '0.85rem' }}>
                    <Trash2 size={15} /> Delete Draft
                  </button>
                )}
              </div>

              {/* 🤖 Buyer Matching Agent panel */}
              <BuyerMatchPanel c={c} />
            </div>
          );
        })
      )}
    </div>
  );
};
