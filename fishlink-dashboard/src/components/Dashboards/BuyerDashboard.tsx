import React, { useState, useEffect } from 'react';
import {
  Bot, MapPin, Package, DollarSign,
  Star, CheckCircle, AlertCircle, RefreshCw,
  ShoppingCart, TrendingUp, Fish, X, Settings, Save, Trash2,
} from 'lucide-react';
import axios from 'axios';
import { API_BASE_URL, formatErrorMessage } from '../../config/api';

// ── Types ─────────────────────────────────────────────────────────────────────

interface MatchedCatch {
  id: number;
  fishSpecies: string;
  quantityKg: number;
  askingPricePerKg: number;
  location: string;
  status: string;
  qualityScore: number;
  qualityGrade: string;
  photoUrl?: string;
  fishermanName: string;
  createdAt: string;
  matchScore: number;
  matchReasons: string;
}

interface BidForm {
  catchId: number;
  species: string;
  askingPrice: number;
  bidPrice: string;
}

interface Preference {
  preferredSpecies: string;
  minQuantityKg: number;
  maxQuantityKg: number;
  maxPricePerKg: number;
  preferredCity: string;
  notes: string;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const matchColor  = (s: number) => s >= 80 ? '#059669' : s >= 60 ? '#d97706' : '#6b7280';
const gradeColor  = (g: string) => g === 'A+' ? '#059669' : g === 'A' ? '#0284c7' : g === 'B' ? '#d97706' : '#9ca3af';
const gradeBg     = (g: string) => g === 'A+' ? '#d1fae5' : g === 'A' ? '#e0f2fe' : g === 'B' ? '#fef3c7' : '#f3f4f6';

const SPECIES = ['', 'Tuna (Yellowfin)', 'Skipjack', 'Trevally (Paraw)', 'Mackerel'];
const CITIES  = ['', 'Negombo', 'Colombo', 'Kandy', 'Galle', 'Matara', 'Jaffna'];

const EMPTY_PREF: Preference = {
  preferredSpecies: '', minQuantityKg: 0, maxQuantityKg: 500,
  maxPricePerKg: 3000, preferredCity: '', notes: '',
};

// ── Score Ring ────────────────────────────────────────────────────────────────

const ScoreRing: React.FC<{ score: number }> = ({ score }) => {
  const r = 22; const circ = 2 * Math.PI * r;
  return (
    <div style={{ position: 'relative', width: 60, height: 60, flexShrink: 0 }}>
      <svg width="60" height="60" style={{ transform: 'rotate(-90deg)' }}>
        <circle cx="30" cy="30" r={r} fill="none" stroke="#e2e8f0" strokeWidth="5" />
        <circle cx="30" cy="30" r={r} fill="none" stroke={matchColor(score)} strokeWidth="5"
          strokeDasharray={`${(score / 100) * circ} ${circ}`} strokeLinecap="round"
          style={{ transition: 'stroke-dasharray 0.6s ease' }} />
      </svg>
      <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center',
        justifyContent: 'center', fontSize: '0.8rem', fontWeight: 800, color: matchColor(score) }}>
        {score}%
      </div>
    </div>
  );
};

// ── Main Component ────────────────────────────────────────────────────────────

export const BuyerDashboard: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'recommend' | 'browse' | 'preferences'>('recommend');

  // Preference state
  const [pref,         setPref]         = useState<Preference>(EMPTY_PREF);
  const [savedPref,    setSavedPref]    = useState<Preference | null>(null);
  const [prefSaving,   setPrefSaving]   = useState(false);
  const [prefSaved,    setPrefSaved]    = useState(false);
  const [prefError,    setPrefError]    = useState('');

  // Results
  const [recommendations, setRecommendations] = useState<MatchedCatch[]>([]);
  const [allCatches,       setAllCatches]      = useState<MatchedCatch[]>([]);
  const [totalAvailable,   setTotalAvailable]  = useState(0);
  const [hasSavedPref,     setHasSavedPref]    = useState(false);

  // UI
  const [loading,    setLoading]    = useState(false);
  const [error,      setError]      = useState('');
  const [searched,   setSearched]   = useState(false);
  const [bidForm,    setBidForm]    = useState<BidForm | null>(null);
  const [bidSuccess, setBidSuccess] = useState(false);
  const [bidError,   setBidError]   = useState('');

  const authHeader = { Authorization: `Bearer ${localStorage.getItem('token')}` };

  // ── Load saved preference + available catches on mount ──────────────────────
  useEffect(() => {
    // Load saved preference
    axios.get<Preference>(`${API_BASE_URL}/api/BuyerMatch/preferences/me`, { headers: authHeader })
      .then(r => {
        setSavedPref(r.data);
        setPref(r.data);
        setHasSavedPref(true);
      })
      .catch(() => {}); // 404 = no pref saved yet, that's fine

    // Load all available catches
    axios.get<MatchedCatch[]>(`${API_BASE_URL}/api/BuyerMatch/available`, { headers: authHeader })
      .then(r => { setAllCatches(r.data); setTotalAvailable(r.data.length); })
      .catch(() => {});

    // Auto-run recommendations using saved preference
    runRecommendations();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // ── Run recommendations ─────────────────────────────────────────────────────
  const runRecommendations = async (customPref?: Preference) => {
    setLoading(true);
    setError('');
    try {
      const body = customPref ? {
        preferredSpecies: customPref.preferredSpecies,
        minQuantityKg:    customPref.minQuantityKg,
        maxQuantityKg:    customPref.maxQuantityKg,
        maxPricePerKg:    customPref.maxPricePerKg,
        preferredCity:    customPref.preferredCity,
        notes:            customPref.notes,
      } : {};

      // Route through ASP.NET Core — NOT directly to port 8000
      const res = await axios.post(
        `${API_BASE_URL}/api/BuyerMatch/recommend`,
        body,
        { headers: authHeader }
      );
      setRecommendations(res.data.recommendations ?? []);
      setTotalAvailable(res.data.totalAvailable ?? 0);
      setHasSavedPref(res.data.hasSavedPref ?? false);
      setSearched(true);
    } catch {
      setError('Could not load recommendations. Make sure the API is running.');
    } finally {
      setLoading(false);
    }
  };

  // ── Save preference ─────────────────────────────────────────────────────────
  const handleSavePreference = async (e: React.FormEvent) => {
    e.preventDefault();
    setPrefSaving(true);
    setPrefError('');
    try {
      await axios.post(
        `${API_BASE_URL}/api/BuyerMatch/preferences/me`,
        {
          preferredSpecies: pref.preferredSpecies,
          minQuantityKg:    pref.minQuantityKg,
          maxQuantityKg:    pref.maxQuantityKg,
          maxPricePerKg:    pref.maxPricePerKg,
          preferredCity:    pref.preferredCity,
          notes:            pref.notes,
        },
        { headers: authHeader }
      );
      setSavedPref({ ...pref });
      setHasSavedPref(true);
      setPrefSaved(true);
      setTimeout(() => setPrefSaved(false), 3000);
      // Re-run recommendations with new preference
      await runRecommendations(pref);
      setActiveTab('recommend');
    } catch {
      setPrefError('Failed to save preferences. Please try again.');
    } finally {
      setPrefSaving(false);
    }
  };

  // ── Delete preference ───────────────────────────────────────────────────────
  const [prefDeleting, setPrefDeleting] = useState(false);

  const handleDeletePreference = async () => {
    if (!window.confirm('Are you sure you want to delete your buying preferences?')) return;
    setPrefDeleting(true);
    setPrefError('');
    try {
      await axios.delete(`${API_BASE_URL}/api/BuyerMatch/preferences/me`, { headers: authHeader });
      setSavedPref(null);
      setHasSavedPref(false);
      setPref({
        preferredSpecies: '',
        minQuantityKg: 0,
        maxQuantityKg: 500,
        maxPricePerKg: 3000,
        preferredCity: '',
        notes: '',
      });
      // Re-run recommendations without saved preference
      await runRecommendations();
    } catch (err: any) {
      setPrefError(formatErrorMessage(err, 'Failed to delete preferences.'));
    } finally {
      setPrefDeleting(false);
    }
  };

  // ── Place bid ───────────────────────────────────────────────────────────────
  const handlePlaceBid = async () => {
    if (!bidForm) return;
    setBidError('');
    const price = Number(bidForm.bidPrice);
    if (!price || price <= 0) { setBidError('Please enter a valid bid price.'); return; }
    try {
      await axios.post(
        `${API_BASE_URL}/api/Bids`,
        { catchId: bidForm.catchId, bidPricePerKg: price },
        { headers: authHeader }
      );
      setBidSuccess(true);
      setTimeout(() => {
        setBidForm(null);
        setBidSuccess(false);
        setRecommendations(prev => prev.map(c => c.id === bidForm.catchId ? { ...c, status: 'Bidding' } : c));
        setAllCatches(prev => prev.map(c => c.id === bidForm.catchId ? { ...c, status: 'Bidding' } : c));
      }, 2000);
    } catch (err: any) {
      setBidError(formatErrorMessage(err, 'Failed to place bid.'));
    }
  };

  // ── Catch card ──────────────────────────────────────────────────────────────
  const renderCatchCard = (c: MatchedCatch, showScore: boolean) => (
    <div key={c.id} className="workflow-card"
      style={{ borderLeftColor: showScore ? matchColor(c.matchScore) : '#3b82f6', marginBottom: 16 }}>
      <div style={{ display: 'flex', gap: 16, alignItems: 'flex-start' }}>
        {showScore && <ScoreRing score={c.matchScore} />}
        {c.photoUrl && (
          <img src={c.photoUrl} alt="catch"
            style={{ width: 80, height: 70, objectFit: 'cover', borderRadius: 8,
              flexShrink: 0, border: '1px solid #e2e8f0' }} />
        )}
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between',
            alignItems: 'flex-start', flexWrap: 'wrap', gap: 8, marginBottom: 8 }}>
            <h3 style={{ margin: 0, color: '#1e293b', fontSize: '1rem' }}>{c.fishSpecies}</h3>
            <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
              {c.qualityGrade !== 'Unverified' && (
                <span style={{ padding: '2px 10px', borderRadius: 12, fontSize: '0.75rem',
                  fontWeight: 700, background: gradeBg(c.qualityGrade), color: gradeColor(c.qualityGrade) }}>
                  Quality {c.qualityGrade}
                </span>
              )}
              <span style={{ padding: '2px 10px', borderRadius: 12, fontSize: '0.75rem', fontWeight: 600,
                background: c.status === 'Bidding' ? '#dbeafe' : '#d1fae5',
                color:      c.status === 'Bidding' ? '#1e40af' : '#065f46' }}>
                {c.status === 'Bidding' ? '🔵 Bidding' : '🟢 Published'}
              </span>
            </div>
          </div>
          <div style={{ display: 'flex', gap: 20, flexWrap: 'wrap', marginBottom: 8 }}>
            <span style={{ display: 'flex', alignItems: 'center', gap: 4, color: '#475569', fontSize: '0.88rem' }}>
              <Package size={14} /> {c.quantityKg} kg
            </span>
            <span style={{ display: 'flex', alignItems: 'center', gap: 4, color: '#475569', fontSize: '0.88rem' }}>
              <DollarSign size={14} /> Rs. {Number(c.askingPricePerKg).toLocaleString()}/kg
            </span>
            <span style={{ display: 'flex', alignItems: 'center', gap: 4, color: '#475569', fontSize: '0.88rem' }}>
              <MapPin size={14} /> {c.location}
            </span>
          </div>
          {showScore && c.matchReasons && (
            <div style={{ background: '#f8fafc', borderRadius: 6, padding: '6px 10px',
              fontSize: '0.78rem', color: '#64748b',
              borderLeft: `3px solid ${matchColor(c.matchScore)}`, marginBottom: 8 }}>
              {c.matchReasons.split(' · ').map((r, i) => (
                <span key={i} style={{ display: 'block', lineHeight: 1.6 }}>{r}</span>
              ))}
            </div>
          )}
          <p style={{ margin: 0, fontSize: '0.75rem', color: '#94a3b8' }}>
            By {c.fishermanName} · {new Date(c.createdAt).toLocaleDateString()}
          </p>
        </div>
      </div>
      <div style={{ marginTop: 14, borderTop: '1px solid #f1f5f9', paddingTop: 12 }}>
        <button className="btn-primary"
          onClick={() => { setBidForm({ catchId: c.id, species: c.fishSpecies,
            askingPrice: Number(c.askingPricePerKg), bidPrice: '' }); setBidError(''); }}
          style={{ display: 'flex', alignItems: 'center', gap: 8,
            padding: '8px 20px', fontSize: '0.88rem', marginTop: 0 }}>
          <ShoppingCart size={15} /> Place Bid
        </button>
      </div>
    </div>
  );

  // ── Bid Modal ───────────────────────────────────────────────────────────────
  const BidModal = () => {
    if (!bidForm) return null;
    return (
      <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)',
        zIndex: 9999, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 20 }}>
        <div style={{ background: 'white', borderRadius: 12, padding: 32,
          width: '100%', maxWidth: 420, boxShadow: '0 20px 40px rgba(0,0,0,0.2)' }}>
          {bidSuccess ? (
            <div style={{ textAlign: 'center', padding: '20px 0' }}>
              <CheckCircle color="#10b981" size={56} style={{ margin: '0 auto 16px' }} />
              <h3 style={{ color: '#065f46', margin: '0 0 8px' }}>Bid Placed!</h3>
              <p style={{ color: '#64748b', margin: 0 }}>Your bid for {bidForm.species} was submitted.</p>
            </div>
          ) : (
            <>
              <div style={{ display: 'flex', justifyContent: 'space-between',
                alignItems: 'center', marginBottom: 20 }}>
                <h3 style={{ margin: 0 }}>Place a Bid</h3>
                <button onClick={() => setBidForm(null)}
                  style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#64748b' }}>
                  <X size={20} />
                </button>
              </div>
              <div style={{ background: '#f8fafc', borderRadius: 8, padding: 14, marginBottom: 20 }}>
                <p style={{ margin: '0 0 4px', fontWeight: 600, color: '#1e293b' }}>{bidForm.species}</p>
                <p style={{ margin: 0, color: '#64748b', fontSize: '0.88rem' }}>
                  Asking: <strong>Rs. {bidForm.askingPrice.toLocaleString()}/kg</strong>
                </p>
              </div>
              {bidError && (
                <div style={{ display: 'flex', gap: 8, background: '#fee2e2', border: '1px solid #fca5a5',
                  borderRadius: 8, padding: 12, marginBottom: 16 }}>
                  <AlertCircle color="#ef4444" size={16} style={{ flexShrink: 0, marginTop: 2 }} />
                  <p style={{ margin: 0, color: '#991b1b', fontSize: '0.85rem' }}>
                    {typeof bidError === 'string' ? bidError : formatErrorMessage(bidError)}
                  </p>
                </div>
              )}
              <div className="form-group" style={{ marginBottom: 20 }}>
                <label>Your Bid Price (Rs/kg)</label>
                <input type="number" placeholder={`e.g. ${bidForm.askingPrice}`}
                  value={bidForm.bidPrice}
                  onChange={e => setBidForm({ ...bidForm, bidPrice: e.target.value })}
                  style={{ padding: 12, border: '1px solid #cbd5e1', borderRadius: 6,
                    fontSize: '1rem', width: '100%', boxSizing: 'border-box' as const }} />
                {bidForm.bidPrice && Number(bidForm.bidPrice) < bidForm.askingPrice && (
                  <p style={{ margin: '4px 0 0', fontSize: '0.78rem', color: '#d97706' }}>
                    ⚠ Below asking price — seller may decline.
                  </p>
                )}
              </div>
              <div style={{ display: 'flex', gap: 10 }}>
                <button className="btn-outline" onClick={() => setBidForm(null)} style={{ flex: 1 }}>Cancel</button>
                <button className="btn-primary" onClick={handlePlaceBid}
                  style={{ flex: 2, marginTop: 0, display: 'flex', alignItems: 'center',
                    justifyContent: 'center', gap: 8 }}>
                  <ShoppingCart size={16} /> Confirm Bid
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    );
  };

  // ── Main Render ─────────────────────────────────────────────────────────────
  return (
    <div className="dashboard-content">
      <BidModal />

      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between',
        alignItems: 'flex-start', flexWrap: 'wrap', gap: 12, marginBottom: 4 }}>
        <div>
          <h2 style={{ margin: 0 }}>Live Market & AI Buyer Matching</h2>
          <p style={{ color: '#64748b', margin: '6px 0 0', fontSize: '0.9rem' }}>
            {totalAvailable} listings available ·{' '}
            {hasSavedPref
              ? '✅ Recommendations based on your saved preferences'
              : '⚠ Set your preferences for better recommendations'}
          </p>
        </div>
      </div>

      {/* Tabs */}
      <div style={{ display: 'flex', gap: 4, marginTop: 20, marginBottom: 24,
        background: '#f1f5f9', borderRadius: 10, padding: 4, width: 'fit-content' }}>
        {([
          { key: 'recommend', label: '🤖 Recommendations' },
          { key: 'browse',    label: '📋 Browse All' },
          { key: 'preferences', label: '⚙️ My Preferences' },
        ] as const).map(tab => (
          <button key={tab.key} onClick={() => setActiveTab(tab.key)}
            style={{
              padding: '8px 18px', borderRadius: 8, border: 'none', cursor: 'pointer',
              fontWeight: 600, fontSize: '0.85rem', transition: 'all 0.2s',
              background: activeTab === tab.key ? 'white' : 'transparent',
              color:      activeTab === tab.key ? '#005b96' : '#64748b',
              boxShadow:  activeTab === tab.key ? '0 1px 4px rgba(0,0,0,0.1)' : 'none',
              position: 'relative' as const,
            }}>
            {tab.label}
            {tab.key === 'preferences' && !hasSavedPref && (
              <span style={{ position: 'absolute', top: 4, right: 4, width: 8, height: 8,
                background: '#f59e0b', borderRadius: '50%', display: 'block' }} />
            )}
          </button>
        ))}
      </div>

      {/* ── Recommendations Tab ────────────────────────────────────────────── */}
      {activeTab === 'recommend' && (
        <>
          {/* Preference summary banner */}
          {hasSavedPref && savedPref && (
            <div style={{ background: '#f0f9ff', border: '1px solid #bae6fd', borderRadius: 10,
              padding: '12px 16px', marginBottom: 20, display: 'flex', justifyContent: 'space-between',
              alignItems: 'center', flexWrap: 'wrap', gap: 10 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <Bot size={18} color="#0369a1" />
                <div style={{ fontSize: '0.85rem', color: '#0369a1' }}>
                  <strong>Preferences active:</strong>{' '}
                  {savedPref.preferredSpecies || 'Any species'} ·{' '}
                  {savedPref.minQuantityKg}–{savedPref.maxQuantityKg}kg ·{' '}
                  Rs.{savedPref.maxPricePerKg.toLocaleString()} max ·{' '}
                  {savedPref.preferredCity || 'Any city'}
                </div>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <button onClick={() => setActiveTab('preferences')}
                  className="btn-outline"
                  style={{ padding: '5px 14px', fontSize: '0.8rem', display: 'flex',
                    alignItems: 'center', gap: 6 }}>
                  <Settings size={13} /> Edit
                </button>
                <button onClick={handleDeletePreference}
                  disabled={prefDeleting}
                  className="btn-outline"
                  style={{
                    padding: '5px 14px',
                    fontSize: '0.8rem',
                    display: 'flex',
                    alignItems: 'center',
                    gap: 6,
                    color: '#dc2626',
                    borderColor: '#fca5a5',
                    background: '#ffffff',
                    cursor: prefDeleting ? 'not-allowed' : 'pointer',
                    opacity: prefDeleting ? 0.6 : 1
                  }}
                  title="Delete Preferences">
                  <Trash2 size={13} /> {prefDeleting ? 'Deleting...' : 'Delete'}
                </button>
              </div>
            </div>
          )}

          {/* No preference yet — nudge */}
          {!hasSavedPref && (
            <div style={{ background: '#fffbeb', border: '1px solid #fde68a', borderRadius: 10,
              padding: '14px 16px', marginBottom: 20 }}>
              <p style={{ margin: '0 0 8px', fontWeight: 600, color: '#92400e', fontSize: '0.9rem' }}>
                ⚡ Get personalised recommendations
              </p>
              <p style={{ margin: '0 0 12px', color: '#78350f', fontSize: '0.85rem' }}>
                Save your fish preferences once — we'll automatically rank the best catches for you every time.
              </p>
              <button onClick={() => setActiveTab('preferences')} className="btn-primary"
                style={{ display: 'flex', alignItems: 'center', gap: 8,
                  padding: '8px 18px', fontSize: '0.85rem', marginTop: 0 }}>
                <Settings size={14} /> Set My Preferences
              </button>
            </div>
          )}

          {/* Refresh */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 20 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <Bot size={20} color="#005b96" />
              <h3 style={{ margin: 0, color: '#1e293b' }}>🤖 Recommended for You</h3>
            </div>
            <button onClick={() => runRecommendations(savedPref ?? undefined)}
              className="btn-outline"
              style={{ display: 'flex', alignItems: 'center', gap: 6,
                padding: '6px 14px', fontSize: '0.8rem' }}>
              <RefreshCw size={13} /> Refresh
            </button>
          </div>

          {/* Error */}
          {error && (
            <div style={{ display: 'flex', gap: 10, background: '#fee2e2', border: '1px solid #fca5a5',
              borderRadius: 8, padding: 14, marginBottom: 20 }}>
              <AlertCircle color="#ef4444" size={18} style={{ flexShrink: 0 }} />
              <p style={{ margin: 0, color: '#991b1b', fontSize: '0.85rem' }}>{error}</p>
            </div>
          )}

          {loading && (
            <div style={{ textAlign: 'center', padding: 40, color: '#64748b' }}>
              <RefreshCw size={28} color="#005b96"
                style={{ animation: 'spin 1s linear infinite', marginBottom: 10 }} />
              <p>Running AI recommendations…</p>
            </div>
          )}

          {!loading && searched && recommendations.length === 0 && (
            <div className="workflow-card" style={{ textAlign: 'center', padding: 40 }}>
              <Fish size={48} color="#94a3b8" style={{ marginBottom: 12 }} />
              <h3 style={{ color: '#475569' }}>No matching catches found</h3>
              <p style={{ color: '#94a3b8' }}>
                Try adjusting your preferences or check back when new catches are published.
              </p>
            </div>
          )}

          {!loading && recommendations.map(c => renderCatchCard(c, true))}

          {!loading && !searched && (
            <div style={{ textAlign: 'center', padding: '40px 20px', color: '#94a3b8' }}>
              <TrendingUp size={48} style={{ marginBottom: 12, opacity: 0.4 }} />
              <p>Loading recommendations…</p>
            </div>
          )}
        </>
      )}

      {/* ── Browse All Tab ────────────────────────────────────────────────── */}
      {activeTab === 'browse' && (
        <>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 20 }}>
            <Star size={18} color="#f59e0b" />
            <h3 style={{ margin: 0 }}>All Available Listings ({allCatches.length})</h3>
          </div>
          {allCatches.length === 0 ? (
            <div className="workflow-card" style={{ textAlign: 'center', padding: 40 }}>
              <Fish size={48} color="#94a3b8" style={{ marginBottom: 12 }} />
              <h3 style={{ color: '#475569' }}>No listings available yet</h3>
            </div>
          ) : (
            allCatches.map(c => renderCatchCard(c, false))
          )}
        </>
      )}

      {/* ── Preferences Tab ───────────────────────────────────────────────── */}
      {activeTab === 'preferences' && (
        <div style={{ maxWidth: 560 }}>
          <div style={{ marginBottom: 24 }}>
            <h3 style={{ margin: '0 0 6px', display: 'flex', alignItems: 'center', gap: 8 }}>
              <Settings size={20} color="#005b96" /> My Buying Preferences
            </h3>
            <p style={{ margin: 0, color: '#64748b', fontSize: '0.88rem' }}>
              These are saved once and used to automatically rank catches for you.
              The AI recommendation score is calculated from your preferences + your bid history.
            </p>
          </div>

          {prefSaved && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, background: '#d1fae5',
              border: '1px solid #6ee7b7', borderRadius: 8, padding: '10px 14px', marginBottom: 16 }}>
              <CheckCircle color="#059669" size={18} />
              <p style={{ margin: 0, color: '#065f46', fontWeight: 600, fontSize: '0.88rem' }}>
                Preferences saved! Recommendations updated.
              </p>
            </div>
          )}

          {prefError && (
            <div style={{ display: 'flex', gap: 8, background: '#fee2e2', border: '1px solid #fca5a5',
              borderRadius: 8, padding: 12, marginBottom: 16 }}>
              <AlertCircle color="#ef4444" size={16} style={{ flexShrink: 0 }} />
              <p style={{ margin: 0, color: '#991b1b', fontSize: '0.85rem' }}>{prefError}</p>
            </div>
          )}

          <form onSubmit={handleSavePreference} className="workflow-card">
            <div style={{ display: 'grid', gap: 16 }}>

              <div className="form-group" style={{ margin: 0 }}>
                <label>Preferred Fish Species</label>
                <select value={pref.preferredSpecies}
                  onChange={e => setPref({ ...pref, preferredSpecies: e.target.value })}>
                  <option value="">Any species</option>
                  {SPECIES.filter(s => s).map(s => <option key={s}>{s}</option>)}
                </select>
                <p style={{ margin: '4px 0 0', fontSize: '0.75rem', color: '#94a3b8' }}>
                  Species match gives 40 points in the recommendation score.
                </p>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                <div className="form-group" style={{ margin: 0 }}>
                  <label>Min Quantity (kg)</label>
                  <input type="number" min="0" value={pref.minQuantityKg}
                    onChange={e => setPref({ ...pref, minQuantityKg: Number(e.target.value) })} />
                </div>
                <div className="form-group" style={{ margin: 0 }}>
                  <label>Max Quantity (kg)</label>
                  <input type="number" min="0" value={pref.maxQuantityKg}
                    onChange={e => setPref({ ...pref, maxQuantityKg: Number(e.target.value) })} />
                </div>
              </div>

              <div className="form-group" style={{ margin: 0 }}>
                <label>Maximum Price (Rs/kg)</label>
                <input type="number" min="0" value={pref.maxPricePerKg}
                  onChange={e => setPref({ ...pref, maxPricePerKg: Number(e.target.value) })}
                  placeholder="e.g. 2500" />
                <p style={{ margin: '4px 0 0', fontSize: '0.75rem', color: '#94a3b8' }}>
                  Catches within your budget get up to 20 extra points.
                </p>
              </div>

              <div className="form-group" style={{ margin: 0 }}>
                <label>Preferred City / Area</label>
                <select value={pref.preferredCity}
                  onChange={e => setPref({ ...pref, preferredCity: e.target.value })}>
                  {CITIES.map(c => <option key={c} value={c}>{c || 'Any location'}</option>)}
                </select>
              </div>

              <div className="form-group" style={{ margin: 0 }}>
                <label>Additional Notes (optional)</label>
                <input type="text" value={pref.notes}
                  onChange={e => setPref({ ...pref, notes: e.target.value })}
                  placeholder="e.g. Fresh only, minimum quality A" />
              </div>
            </div>

            {/* Score breakdown info */}
            <div style={{ background: '#f0f9ff', borderRadius: 8, padding: '12px 14px',
              margin: '20px 0', border: '1px solid #bae6fd' }}>
              <p style={{ margin: '0 0 8px', fontWeight: 700, color: '#0369a1', fontSize: '0.85rem' }}>
                📊 How your recommendation score is calculated:
              </p>
              {[
                ['Species match',    '40 pts'],
                ['Quantity range',   '25 pts'],
                ['Price within budget', '20 pts'],
                ['Location match',   '10 pts'],
                ['Past bid history', '10 pts'],
                ['Quality + freshness', '10 pts'],
              ].map(([label, pts]) => (
                <div key={label} style={{ display: 'flex', justifyContent: 'space-between',
                  fontSize: '0.8rem', color: '#334155', marginBottom: 3 }}>
                  <span>{label}</span>
                  <strong style={{ color: '#005b96' }}>{pts}</strong>
                </div>
              ))}
            </div>

            <button type="submit" className="btn-primary"
              disabled={prefSaving}
              style={{ width: '100%', display: 'flex', alignItems: 'center',
                justifyContent: 'center', gap: 8, opacity: prefSaving ? 0.7 : 1 }}>
              {prefSaving
                ? <><RefreshCw size={16} style={{ animation: 'spin 1s linear infinite' }} /> Saving…</>
                : <><Save size={16} /> Save Preferences & Update Recommendations</>}
            </button>
          </form>
        </div>
      )}

      <style>{`@keyframes spin { from{transform:rotate(0deg)} to{transform:rotate(360deg)} }`}</style>
    </div>
  );
};
