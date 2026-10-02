import React, { useState } from 'react';
import { Eye, EyeOff } from 'lucide-react';

interface PasswordInputProps extends Omit<React.InputHTMLAttributes<HTMLInputElement>, 'type'> {
  accessibleLabel: string;
}

export const PasswordInput: React.FC<PasswordInputProps> = ({ accessibleLabel, style, ...inputProps }) => {
  const [visible, setVisible] = useState(false);

  return (
    <div className="password-input-wrap">
      <input
        {...inputProps}
        type={visible ? 'text' : 'password'}
        style={{ width: '100%', boxSizing: 'border-box', ...style, paddingRight: '44px' }}
      />
      <button
        type="button"
        className="password-toggle"
        aria-label={visible ? `Hide ${accessibleLabel}` : `Show ${accessibleLabel}`}
        aria-pressed={visible}
        onClick={() => setVisible(!visible)}
      >
        {visible ? <EyeOff size={18} /> : <Eye size={18} />}
      </button>
    </div>
  );
};