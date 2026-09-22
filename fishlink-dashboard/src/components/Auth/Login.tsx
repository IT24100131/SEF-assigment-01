import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Fish } from 'lucide-react';
import axios from 'axios';
import { API_BASE_URL } from '../../config/api';

export const Login = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const navigate = useNavigate();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const response = await axios.post(`${API_BASE_URL}/api/Auth/login`, {
        email,
        password
      });
      
      const { token, user } = response.data;
      localStorage.setItem('token', token);
      localStorage.setItem('role', user.role);
      
      navigate('/dashboard');
    } catch (err: any) {
      setError(err.response?.data || 'Invalid credentials');
    }
  };

  return (
    <div className="auth-container">
      <div className="auth-card">
        <div className="auth-header">
          <Fish color="#005b96" size={48} />
          <h2>Welcome to FishLink AI</h2>
          <p>Sign in to your account</p>
        </div>
        {error && <div style={{color: 'red', marginBottom: '10px', textAlign: 'center'}}>{error}</div>}
        <form onSubmit={handleLogin} className="auth-form">
          <div className="form-group">
            <label>Email Address</label>
            <input 
              type="email" 
              value={email} 
              onChange={(e) => setEmail(e.target.value)} 
              placeholder="e.g. admin@fishlink.com" 
              required 
            />
          </div>
          <div className="form-group">
            <label>Password</label>
            <input 
              type="password" 
              value={password} 
              onChange={(e) => setPassword(e.target.value)} 
              placeholder="Enter password" 
              required 
            />
          </div>
          <button type="submit" className="btn-primary">Sign In</button>
        </form>
        <div className="auth-footer">
          <p>Don't have an account? <span onClick={() => navigate('/register')} className="link">Register here</span></p>
          <p className="hint">Hint: Ensure you have registered first to test database login!</p>
        </div>
      </div>
    </div>
  );
};
