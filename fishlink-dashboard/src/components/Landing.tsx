import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Fish, ArrowRight, X, CheckCircle, Phone, Mail, MapPin } from 'lucide-react';
import axios from 'axios';
import '../landing.css';
import { API_BASE_URL } from '../config/api';

export const Landing = () => {
  const navigate = useNavigate();
  const [isAuthOpen, setIsAuthOpen] = useState(false);
  const [authView, setAuthView] = useState<'login' | 'register'>('login');

  // Auth States
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [fullName, setFullName] = useState('');
  const [role, setRole] = useState('Fisherman');
  const [error, setError] = useState('');

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const response = await axios.post(`${API_BASE_URL}/api/Auth/login`, { email, password });
      const { token, user } = response.data;
      localStorage.setItem('token', token);
      localStorage.setItem('role', user.role);
      navigate('/dashboard');
    } catch (err: any) {
      if (typeof err.response?.data === 'string') {
        setError(err.response.data);
      } else {
        setError('Invalid credentials');
      }
    }
  };

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await axios.post(`${API_BASE_URL}/api/Auth/register`, {
        fullName, email, passwordHash: password, role
      });
      alert('Registration successful! Please login.');
      setAuthView('login');
      setError('');
    } catch (err: any) {
      if (err.response?.data?.errors) {
        // ASP.NET Validation errors
        const errMap = err.response.data.errors;
        const msg = Object.keys(errMap).map(k => errMap[k].join(' ')).join(' ');
        setError(msg);
      } else if (typeof err.response?.data === 'string' && !err.response.data.includes('<html')) {
        setError(err.response.data);
      } else {
        setError('Registration failed (Server Error)');
      }
    }
  };

  const openAuth = (view: 'login' | 'register') => {
    setAuthView(view);
    setIsAuthOpen(true);
    setError('');
  };

  const scrollTo = (id: string) => {
    const el = document.getElementById(id);
    if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  };

  return (
    <div className="landing-container">
      {/* Navbar */}
      <nav className="landing-nav">
        <div className="logo-container" style={{backgroundColor: 'transparent', padding: '0'}}>
          <Fish color="#005b96" size={32} />
          <h2 style={{color: '#005b96', margin: '0 0 0 10px'}}>FishLink AI</h2>
        </div>

        {/* Nav links */}
        <div className="nav-center-links">
          <span onClick={() => scrollTo('how-it-works')}>How It Works</span>
          <span onClick={() => scrollTo('details')}>Features</span>
          <span onClick={() => scrollTo('stats')}>About</span>
          <span onClick={() => scrollTo('footer')}>Contact</span>
        </div>

        <div className="nav-links">
          <button onClick={() => openAuth('login')} className="btn-outline">Sign In</button>
          <button onClick={() => openAuth('register')} className="btn-primary" style={{margin: 0}}>Get Started</button>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="hero-section">
        <div className="hero-overlay"></div>
        <div className="hero-content">
          <h1>Smart Fish Trading & Cold-Chain Logistics</h1>
          <p style={{fontSize: '1.3rem', maxWidth: '800px', margin: '0 auto 30px'}}>
            Connect directly from the Negombo shores to wholesale buyers. 
            AI-powered market intelligence, quality verification, and automated cold-chain logistics in one platform.
          </p>
          <button onClick={() => openAuth('register')} className="btn-primary hero-btn" style={{marginTop: '20px'}}>
            Join the Platform <ArrowRight size={20} />
          </button>
        </div>
      </section>

      {/* ── How It Works ──────────────────────────────────────────────── */}
      <section id="how-it-works" className="how-section">
        <div className="section-header">
          <h2>How FishLink AI Works</h2>
          <p>From pier to buyer in 5 automated steps</p>
        </div>
        <div className="steps-row">
          {[
            { num: '01', title: 'Register Your Catch', desc: 'Fisherman uploads photo, weight, species and GPS location from the pier.' },
            { num: '02', title: 'AI Quality Check', desc: 'Our AI agent validates the listing, detects anomalies and assigns a quality grade.' },
            { num: '03', title: 'Price Intelligence', desc: 'Market agent analyses 90-day history and recommends the optimal asking price.' },
            { num: '04', title: 'Buyer Matching', desc: 'Buyers with matching preferences are notified. Bidding opens automatically.' },
            { num: '05', title: 'Logistics & Delivery', desc: 'Winning bid triggers cold-chain vehicle assignment. GPS-tracked delivery begins.' },
          ].map((s, i) => (
            <div className="step-item" key={i}>
              <div className="step-num">{s.num}</div>
              {i < 4 && <div className="step-arrow">→</div>}
              <h4>{s.title}</h4>
              <p>{s.desc}</p>
            </div>
          ))}
        </div>
      </section>

      {/* ── Stats Section ─────────────────────────────────────────────── */}
      <section id="stats" className="stats-section">
        {[
          { value: '2,400+', label: 'Catches Listed' },
          { value: 'Rs. 18M+', label: 'Trade Volume' },
          { value: '94%', label: 'Quality Accuracy' },
          { value: '47 min', label: 'Avg. Delivery Time' },
        ].map((s, i) => (
          <div className="stat-item" key={i}>
            <h2>{s.value}</h2>
            <p>{s.label}</p>
          </div>
        ))}
      </section>

      {/* ── Advanced Details Section ──────────────────────────────────── */}
      <section id="details" className="advanced-details">
        <div className="detail-row">
          <div className="detail-text">
            <span className="detail-tag">🤖 AI Agent</span>
            <h2 style={{color: '#005b96', fontSize: '2rem', marginTop: '12px'}}>
              AI Quality Verification & Price Intelligence
            </h2>
            <p style={{fontSize: '1.05rem', color: '#475569', lineHeight: '1.7'}}>
              When a fisherman uploads a catch, our <strong>Quality Validation Agent</strong> instantly
              analyses the photo to verify species and estimate freshness. Simultaneously, the
              <strong> Market Intelligence Agent</strong> queries 90 days of historical price data from
              our dedicated Price API — blending it with live DB transaction averages to produce a
              weighted recommended selling price unique to each catch.
            </p>
            <ul className="detail-list">
              <li><CheckCircle size={16} color="#10b981" /> Species & freshness verification via photo AI</li>
              <li><CheckCircle size={16} color="#10b981" /> 90-day WMA price model + live DB blend (60/40)</li>
              <li><CheckCircle size={16} color="#10b981" /> 7-day price forecast with confidence rating</li>
              <li><CheckCircle size={16} color="#10b981" /> Fraud & anomaly detection before listing goes live</li>
            </ul>
            <button onClick={() => openAuth('register')} className="btn-primary detail-btn">
              Start Listing Catches <ArrowRight size={18} />
            </button>
          </div>
          <div className="detail-image">
            <img src="/quality.jpg" alt="Quality Inspection"
              style={{width: '100%', height: '380px', objectFit: 'cover',
                borderRadius: '16px', boxShadow: '0 20px 40px rgba(0,0,0,0.15)'}} />
          </div>
        </div>

        <div className="detail-row reverse">
          <div className="detail-text">
            <span className="detail-tag" style={{background: '#fef3c7', color: '#92400e'}}>
              🚛 Logistics Agent
            </span>
            <h2 style={{color: '#f59e0b', fontSize: '2rem', marginTop: '12px'}}>
              Smart Buyer Matching & Cold-Chain Logistics
            </h2>
            <p style={{fontSize: '1.05rem', color: '#475569', lineHeight: '1.7'}}>
              Once a catch is published, the <strong>Buyer Matching Agent</strong> scores all registered
              buyers using their saved preferences (species, quantity, budget, location) and past bid history —
              surfacing the most compatible buyers first. When a bid is accepted, the
              <strong> Logistics Agent</strong> automatically assigns the nearest refrigerated vehicle
              and optimises the cold-chain route from the Negombo pier to the buyer's warehouse.
            </p>
            <ul className="detail-list">
              <li><CheckCircle size={16} color="#f59e0b" /> Preference-based buyer scoring (species 40 · qty 25 · price 20 · location 10)</li>
              <li><CheckCircle size={16} color="#f59e0b" /> Bid history bonus — repeat buyers ranked higher</li>
              <li><CheckCircle size={16} color="#f59e0b" /> Automatic refrigerated vehicle assignment on bid win</li>
              <li><CheckCircle size={16} color="#f59e0b" /> GPS-optimised cold-chain routing — avg 47 min ETA</li>
            </ul>
            <button onClick={() => openAuth('register')} className="btn-primary detail-btn"
              style={{background: '#f59e0b', borderColor: '#f59e0b'}}>
              Join as a Buyer <ArrowRight size={18} />
            </button>
          </div>
          <div className="detail-image">
            <img src="/truck.jpg" alt="Logistics Truck"
              style={{width: '100%', height: '380px', objectFit: 'cover',
                borderRadius: '16px', boxShadow: '0 20px 40px rgba(0,0,0,0.15)'}} />
          </div>
        </div>
      </section>

      {/* ── CTA Section ───────────────────────────────────────────────── */}
      <section className="cta-section">
        <div className="cta-content">
          <h2>Ready to Transform Your Fish Trading?</h2>
          <p>Join thousands of fishermen and buyers already using FishLink AI on the Negombo coast.</p>
          <div className="cta-buttons">
            <button onClick={() => openAuth('register')} className="btn-primary cta-btn">
              Get Started Free <ArrowRight size={18} />
            </button>
            <button onClick={() => openAuth('login')} className="cta-btn-outline">
              Sign In to Your Account
            </button>
          </div>
        </div>
      </section>

      {/* ── Footer ────────────────────────────────────────────────────── */}
      <footer id="footer" className="landing-footer">
        <div className="footer-top">
          <div className="footer-brand">
            <div style={{display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '16px'}}>
              <Fish color="#6ee7b7" size={28} />
              <span style={{fontSize: '1.3rem', fontWeight: 700, color: 'white'}}>FishLink AI</span>
            </div>
            <p>Sri Lanka's first AI-powered fish trading and cold-chain logistics platform. Built for the Negombo fishing community.</p>
            <div className="footer-social">
              <span>🐟</span><span>🌊</span><span>🤖</span>
            </div>
          </div>

          <div className="footer-links">
            <h4>Platform</h4>
            <ul>
              <li onClick={() => openAuth('register')}>For Fishermen</li>
              <li onClick={() => openAuth('register')}>For Buyers</li>
              <li onClick={() => openAuth('register')}>For Logistics</li>
              <li onClick={() => openAuth('register')}>Admin Portal</li>
            </ul>
          </div>

          <div className="footer-links">
            <h4>Features</h4>
            <ul>
              <li>AI Quality Check</li>
              <li>Market Trends</li>
              <li>Buyer Matching</li>
              <li>Cold-Chain Logistics</li>
            </ul>
          </div>

          <div className="footer-links">
            <h4>Contact</h4>
            <ul>
              <li><Mail size={14} /> info@fishlink.lk</li>
              <li><Phone size={14} /> +94 31 222 3456</li>
              <li><MapPin size={14} /> Negombo, Sri Lanka</li>
            </ul>
          </div>
        </div>

        <div className="footer-bottom">
          <p>© 2026 FishLink AI. All rights reserved. Built for Sri Lanka's fishing industry.</p>
          <div className="footer-bottom-links">
            <span>Privacy Policy</span>
            <span>Terms of Service</span>
            <span>Support</span>
          </div>
        </div>
      </footer>

      {/* Side Auth Panel */}
      <div className={`auth-sidepanel ${isAuthOpen ? 'open' : ''}`}>
        <div className="auth-panel-content">
          <button className="close-btn" onClick={() => setIsAuthOpen(false)}><X size={24} /></button>
          
          <div className="auth-header" style={{marginTop: '40px'}}>
            <Fish color="#005b96" size={48} />
            <h2>{authView === 'login' ? 'Welcome Back' : 'Create Account'}</h2>
            <p>{authView === 'login' ? 'Sign in to your account' : 'Join the FishLink platform'}</p>
          </div>

          {error && <div style={{color: 'red', marginBottom: '15px', textAlign: 'center', backgroundColor: '#fee2e2', padding: '10px', borderRadius: '6px'}}>{error}</div>}

          {authView === 'login' ? (
            <form onSubmit={handleLogin} className="auth-form">
              <div className="form-group">
                <label>Email Address</label>
                <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="e.g. admin@fishlink.com" required />
              </div>
              <div className="form-group">
                <label>Password</label>
                <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} placeholder="Enter password" required />
              </div>
              <button type="submit" className="btn-primary" style={{marginTop: '10px'}}>Sign In</button>
              <div className="auth-footer" style={{marginTop: '20px'}}>
                <p>Don't have an account? <span onClick={() => setAuthView('register')} className="link">Register here</span></p>
              </div>
            </form>
          ) : (
            <form onSubmit={handleRegister} className="auth-form">
              <div className="form-group">
                <label>Full Name</label>
                <input type="text" placeholder="e.g. John Doe" required value={fullName} onChange={e => setFullName(e.target.value)} />
              </div>
              <div className="form-group">
                <label>Email Address</label>
                <input type="email" placeholder="e.g. john@example.com" required value={email} onChange={e => setEmail(e.target.value)} />
              </div>
              <div className="form-group">
                <label>Password</label>
                <input type="password" placeholder="Enter password" required value={password} onChange={e => setPassword(e.target.value)} />
              </div>
              <div className="form-group">
                <label>Select Your Role</label>
                <select value={role} onChange={(e) => setRole(e.target.value)}>
                  <option value="Fisherman">Fisherman</option>
                  <option value="Buyer">Buyer</option>
                  <option value="Admin">Admin</option>
                </select>
              </div>
              <button type="submit" className="btn-primary" style={{marginTop: '10px'}}>Register</button>
              <div className="auth-footer" style={{marginTop: '20px'}}>
                <p>Already have an account? <span onClick={() => setAuthView('login')} className="link">Sign In</span></p>
              </div>
            </form>
          )}
        </div>
      </div>
      
      {/* Overlay for side panel */}
      {isAuthOpen && <div className="panel-overlay" onClick={() => setIsAuthOpen(false)}></div>}
    </div>
  );
};
