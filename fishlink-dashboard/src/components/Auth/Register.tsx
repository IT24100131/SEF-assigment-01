import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Fish } from 'lucide-react';
import axios from 'axios';
import { API_BASE_URL } from '../../config/api';
import { PasswordInput } from './PasswordInput';

export const Register = () => {
  const [role, setRole] = useState('Fisherman');
  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState('');
  const navigate = useNavigate();

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    if (fullName.trim().length < 2) {
      setError('Enter a name with at least 2 characters.');
      return;
    }
    if (password.length < 8) {
      setError('Password must be at least 8 characters.');
      return;
    }
    if (password !== confirmPassword) {
      setError('Passwords do not match.');
      return;
    }
    if (!window.confirm('Create this FishLink account?')) return;
    try {
      await axios.post(`${API_BASE_URL}/api/Auth/register`, {
        fullName: fullName.trim(),
        email: email.trim(),
        passwordHash: password, // Simply using the plain password for demo, API should hash
        role
      });
      alert('Registration successful! Please login.');
      navigate('/login');
    } catch (err: any) {
      setError(err.response?.data || 'Registration failed');
    }
  };

  return (
    <div className="auth-container">
      <div className="auth-card">
        <div className="auth-header">
          <Fish color="#005b96" size={48} />
          <h2>Create an Account</h2>
          <p>Join the FishLink platform</p>
        </div>
        {error && <div style={{color: 'red', marginBottom: '10px', textAlign: 'center'}}>{error}</div>}
        <form onSubmit={handleRegister} className="auth-form">
          <div className="form-group">
            <label>Full Name</label>
            <input type="text" placeholder="e.g. John Doe" required minLength={2} value={fullName} onChange={e => setFullName(e.target.value)} />
          </div>
          <div className="form-group">
            <label>Email Address</label>
            <input type="email" placeholder="e.g. john@example.com" required value={email} onChange={e => setEmail(e.target.value)} />
          </div>
          <div className="form-group">
            <label>Password</label>
            <PasswordInput accessibleLabel="password" autoComplete="new-password" placeholder="At least 8 characters" required minLength={8} value={password} onChange={e => setPassword(e.target.value)} />
          </div>
          <div className="form-group">
            <label>Confirm Password</label>
            <PasswordInput accessibleLabel="confirm password" autoComplete="new-password" placeholder="Re-enter password" required minLength={8} value={confirmPassword} onChange={e => setConfirmPassword(e.target.value)} />
          </div>
          <div className="form-group">
            <label>Select Your Role</label>
            <select value={role} onChange={(e) => setRole(e.target.value)}>
              <option value="Fisherman">Fisherman</option>
              <option value="Buyer">Buyer</option>
            </select>
          </div>
          <button type="submit" className="btn-primary">Register</button>
        </form>
        <div className="auth-footer">
          <p>Already have an account? <span onClick={() => navigate('/login')} className="link">Sign In</span></p>
        </div>
      </div>
    </div>
  );
};
