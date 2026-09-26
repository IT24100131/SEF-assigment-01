import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, useNavigate } from 'react-router-dom';
import { Fish, MapPin, Activity, Ship, ShoppingCart, LogOut, ShieldAlert, Moon, Sun } from 'lucide-react';
import { Login } from './components/Auth/Login';
import { Register } from './components/Auth/Register';
import { Landing } from './components/Landing';
import { FishermanDashboard } from './components/Dashboards/FishermanDashboard';
import { MarketTrends } from './components/Dashboards/MarketTrends';
import { BuyerDashboard } from './components/Dashboards/BuyerDashboard';
import { AdminDashboard } from './components/Dashboards/AdminDashboard';
import { LogisticsDashboard } from './components/Dashboards/LogisticsDashboard';
import './App.css';



const DashboardLayout = () => {
  const role = localStorage.getItem('role') || 'Admin';
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState('home');
  const [isDark, setIsDark] = useState(() => localStorage.getItem('theme') === 'dark');

  useEffect(() => {
    if (isDark) {
      document.body.setAttribute('data-theme', 'dark');
      localStorage.setItem('theme', 'dark');
    } else {
      document.body.removeAttribute('data-theme');
      localStorage.setItem('theme', 'light');
    }
  }, [isDark]);

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
          defaultTab={activeTab === 'workflows' ? 'workflows' : activeTab === 'marketplace' ? 'marketplace' : 'flagged'}
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
          <Fish color="var(--primary)" size={32} />
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
                <li className={activeTab === 'marketplace' ? 'active' : ''} onClick={() => setActiveTab('marketplace')}>
                  <Fish size={18} /> <span>Published Market</span>
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
        <div style={{ marginTop: 'auto', padding: '20px' }}>
          <button className="btn-reject" onClick={handleLogout}
            style={{ width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '10px' }}>
            <LogOut size={16} /> Logout ({role})
          </button>
        </div>
      </aside>

      <main className="main-content">
        <header>
          <h1>{role} Portal</h1>
          <div className="header-right">
            <button className="theme-toggle" onClick={() => setIsDark(!isDark)} title="Toggle Dark Mode">
              {isDark ? <Sun size={20} /> : <Moon size={20} />}
            </button>
            <div className="user-profile">{role} User</div>
          </div>
        </header>
        {renderContent()}
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
