import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, useNavigate } from 'react-router-dom';
import { Fish, MapPin, Activity, Ship, ShoppingCart, LogOut, ShieldAlert, Settings } from 'lucide-react';
import axios from 'axios';
import { Login } from './components/Auth/Login';
import { Register } from './components/Auth/Register';
import { Landing } from './components/Landing';
import { FishermanDashboard } from './components/Dashboards/FishermanDashboard';
import { MarketTrends } from './components/Dashboards/MarketTrends';
import { BuyerDashboard } from './components/Dashboards/BuyerDashboard';
import { AdminDashboard } from './components/Dashboards/AdminDashboard';
import { LogisticsDashboard } from './components/Dashboards/LogisticsDashboard';
import { AccountSettingsModal } from './components/AccountSettingsModal';
import { API_BASE_URL } from './config/api';
import './App.css';

const DashboardLayout = () => {
  const role = localStorage.getItem('role') || 'Admin';
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState('home');
  const [showSettings, setShowSettings] = useState(false);
  const [userName, setUserName] = useState<string>('');

  useEffect(() => {
    const fetchUser = async () => {
      try {
        const token = localStorage.getItem('token');
        if (!token) return;
        const res = await axios.get(`${API_BASE_URL}/api/Users/me`, {
          headers: { Authorization: `Bearer ${token}` }
        });
        if (res.data?.fullName) {
          setUserName(res.data.fullName);
        }
      } catch {
        try {
          const token = localStorage.getItem('token') ?? '';
          if (token) {
            const payload = JSON.parse(atob(token.split('.')[1]));
            const name = payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'];
            if (name) setUserName(name);
          }
        } catch {}
      }
    };
    fetchUser();
  }, []);

  const handleLogout = () => {
    localStorage.removeItem('role');
    localStorage.removeItem('token');
    navigate('/');
  };

  const renderContent = () => {
    if (role === 'Admin') {
      if (activeTab === 'logistics') {
        return <LogisticsDashboard onNavigateTab={(tab) => setActiveTab(tab)} />;
      }
      return (
        <AdminDashboard
          defaultTab={activeTab === 'workflows' ? 'workflows' : 'flagged'}
        />
      );
    }
    if (role === 'Logistics') {
      return <LogisticsDashboard />;
    }
    if (role === 'Buyer') {
      if (activeTab === 'home')   return <BuyerDashboard />;
      if (activeTab === 'orders') return (
        <div>
          <LogisticsDashboard />
        </div>
      );
    }
    if (role === 'Fisherman') {
      if (activeTab === 'home')   return <FishermanDashboard />;
      if (activeTab === 'market') return <MarketTrends />;
    }
    return null;
  };

  return (
    <div className="dashboard-container">
      <aside className="sidebar">
        <div className="logo-container">
          <Fish color="white" size={32} />
          <h2>FishLink AI</h2>
        </div>
        <nav>
          <ul>
            {role === 'Admin' && (
              <>
                <li className={activeTab === 'home' ? 'active' : ''} onClick={() => setActiveTab('home')}>
                  <ShieldAlert size={18} /> <span>Fraud Review</span>
                </li>
                <li className={activeTab === 'workflows' ? 'active' : ''} onClick={() => setActiveTab('workflows')}>
                  <Activity size={18} /> <span>AI Workflows</span>
                </li>
                <li className={activeTab === 'logistics' ? 'active' : ''} onClick={() => setActiveTab('logistics')}>
                  <MapPin size={18} /> <span>Logistics</span>
                </li>
              </> 
            )}
            {role === 'Logistics' && (
              <>
                <li className={activeTab === 'logistics' || activeTab === 'home' ? 'active' : ''} onClick={() => setActiveTab('logistics')}>
                  <MapPin size={18} /> <span>Logistics Dispatch</span>
                </li>
              </>
            )}
            {role === 'Fisherman' && (
              <>
                <li className={activeTab === 'home'   ? 'active' : ''} onClick={() => setActiveTab('home')}>
                  <Ship size={18} /> <span>My Catches</span>
                </li>
                <li className={activeTab === 'market' ? 'active' : ''} onClick={() => setActiveTab('market')}>
                  <Activity size={18} /> <span>Market Trends</span>
                </li>
              </>
            )}
            {role === 'Buyer' && (
              <>
                <li className={activeTab === 'home'   ? 'active' : ''} onClick={() => setActiveTab('home')}>
                  <ShoppingCart size={18} /> <span>Live Market</span>
                </li>
                <li className={activeTab === 'orders' ? 'active' : ''} onClick={() => setActiveTab('orders')}>
                  <MapPin size={18} /> <span>My Orders</span>
                </li>
              </>
            )}
          </ul>
        </nav>
        <div style={{ marginTop: 'auto', padding: '20px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
          <button
            type="button"
            className="btn-outline"
            onClick={() => setShowSettings(true)}
            style={{ width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px', color: 'white', borderColor: 'rgba(255,255,255,0.3)', padding: '9px 14px', fontSize: '0.85rem' }}
          >
            <Settings size={15} /> Account Settings
          </button>
          <button className="btn-reject" onClick={handleLogout}
            style={{ width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '10px' }}>
            <LogOut size={16} /> Logout ({role})
          </button>
        </div>
      </aside>

      <main className="main-content">
        <header>
          <h1>{role} Portal</h1>
          <div
            className="user-profile"
            onClick={() => setShowSettings(true)}
            title="Click to view and edit Account Settings"
            role="button"
            tabIndex={0}
          >
            <span className="user-profile-avatar">
              {userName ? userName.charAt(0).toUpperCase() : role.charAt(0)}
            </span>
            <span className="user-profile-name">{userName || `${role} User`}</span>
            <Settings size={14} style={{ opacity: 0.6 }} />
          </div>
        </header>
        {renderContent()}

        {showSettings && (
          <AccountSettingsModal
            onClose={() => setShowSettings(false)}
            onUserUpdated={(u) => setUserName(u.fullName)}
          />
        )}
      </main>
    </div>
  );
};

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/" element={<Landing />} />
        <Route path="/login" element={<Login />} />
        <Route path="/register" element={<Register />} />
        <Route path="/dashboard" element={<DashboardLayout />} />
      </Routes>
    </Router>
  );
}

export default App;
