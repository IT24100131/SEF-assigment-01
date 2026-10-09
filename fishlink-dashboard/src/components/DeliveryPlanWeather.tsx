import React, { useState, useEffect } from 'react';
import axios from 'axios';
import {
  CloudSun,
  Wind,
  Thermometer,
  ShieldCheck,
  AlertTriangle,
  Snowflake,
  Navigation,
  Info
} from 'lucide-react';
import { API_BASE_URL } from '../config/api';

export interface DeliveryPlanWeatherProps {
  pickupLocation: string;
  deliveryLocation: string;
  weatherNote?: string;
}

export const extractCity = (loc: string): string => {
  if (!loc) return 'Colombo';
  const lower = loc.toLowerCase();
  if (lower.includes('anuradhapura')) return 'Anuradhapura';
  if (lower.includes('jaffna')) return 'Jaffna';
  if (lower.includes('trincomalee')) return 'Trincomalee';
  if (lower.includes('batticaloa')) return 'Batticaloa';
  if (lower.includes('hambantota')) return 'Hambantota';
  if (lower.includes('tangalle')) return 'Tangalle';
  if (lower.includes('matara')) return 'Matara';
  if (lower.includes('galle')) return 'Galle';
  if (lower.includes('beruwala')) return 'Beruwala';
  if (lower.includes('kalutara')) return 'Kalutara';
  if (lower.includes('puttalam')) return 'Puttalam';
  if (lower.includes('kalpitiya')) return 'Kalpitiya';
  if (lower.includes('chilaw')) return 'Chilaw';
  if (lower.includes('mannar')) return 'Mannar';
  if (lower.includes('kurunegala')) return 'Kurunegala';
  if (lower.includes('dambulla')) return 'Dambulla';
  if (lower.includes('nuwara')) return 'Nuwara Eliya';
  if (lower.includes('badulla')) return 'Badulla';
  if (lower.includes('ratnapura')) return 'Ratnapura';
  if (lower.includes('negombo')) return 'Negombo';
  if (lower.includes('colombo') || lower.includes('peliyagoda')) return 'Colombo';
  if (lower.includes('kandy')) return 'Kandy';
  const first = loc.trim().split(/[\s,]+/)[0];
  return first || 'Colombo';
};

export const DeliveryPlanWeather: React.FC<DeliveryPlanWeatherProps> = ({
  pickupLocation,
  deliveryLocation,
  weatherNote
}) => {
  const [data, setData] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  const fromCity = extractCity(pickupLocation);
  const toCity = extractCity(deliveryLocation);

  useEffect(() => {
    let isMounted = true;
    const authHeader = { Authorization: `Bearer ${localStorage.getItem('token')}` };

    axios
      .get(
        `${API_BASE_URL}/api/Weather/logistics?from=${encodeURIComponent(fromCity)}&to=${encodeURIComponent(toCity)}`,
        { headers: authHeader }
      )
      .then(res => {
        if (isMounted) setData(res.data);
      })
      .catch(() => {})
      .finally(() => {
        if (isMounted) setLoading(false);
      });

    return () => {
      isMounted = false;
    };
  }, [fromCity, toCity]);

  const riskBadge = (r?: string) => {
    const risk = r || 'Low';
    if (risk === 'High') {
      return (
        <span
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: 5,
            fontSize: '0.72rem',
            fontWeight: 700,
            padding: '3px 9px',
            borderRadius: 6,
            background: '#fee2e2',
            color: '#b91c1c',
            border: '1px solid #fca5a5'
          }}
        >
          <AlertTriangle size={13} />
          Transit Risk: High
        </span>
      );
    }
    if (risk === 'Moderate') {
      return (
        <span
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: 5,
            fontSize: '0.72rem',
            fontWeight: 700,
            padding: '3px 9px',
            borderRadius: 6,
            background: '#fef3c7',
            color: '#b45309',
            border: '1px solid #fcd34d'
          }}
        >
          <AlertTriangle size={13} />
          Transit Risk: Moderate
        </span>
      );
    }
    return (
      <span
        style={{
          display: 'inline-flex',
          alignItems: 'center',
          gap: 5,
          fontSize: '0.72rem',
          fontWeight: 700,
          padding: '3px 9px',
          borderRadius: 6,
          background: '#dcfce7',
          color: '#15803d',
          border: '1px solid #86efac'
        }}
      >
        <ShieldCheck size={13} />
        Transit Risk: Low
      </span>
    );
  };

  return (
    <div
      style={{
        background: '#ffffff',
        border: '1px solid #e2e8f0',
        borderRadius: 12,
        padding: '14px 16px',
        marginBottom: 14,
        boxShadow: '0 1px 3px rgba(15, 23, 42, 0.03)'
      }}
    >
      {/* Header Row */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          flexWrap: 'wrap',
          gap: 10,
          marginBottom: 12,
          paddingBottom: 10,
          borderBottom: '1px solid #f1f5f9'
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div
            style={{
              width: 32,
              height: 32,
              borderRadius: 8,
              background: '#f0f9ff',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#0284c7'
            }}
          >
            <CloudSun size={18} />
          </div>
          <div>
            <div style={{ fontWeight: 800, fontSize: '0.86rem', color: '#0f172a' }}>
              Route Meteorology & Driving Telemetry
            </div>
            <div style={{ fontSize: '0.73rem', color: '#64748b', fontWeight: 500 }}>
              {fromCity} ➔ {toCity} · {data?.source || 'Live Open-Meteo Satellite Feed'}
            </div>
          </div>
        </div>

        {riskBadge(data?.overallDrivingRisk)}
      </div>

      {data ? (
        <>
          {/* Dual Origin / Destination Telemetry Cards */}
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
              gap: 10,
              marginBottom: 10
            }}
          >
            {/* Origin Card */}
            <div
              style={{
                background: '#f8fafc',
                borderRadius: 8,
                padding: '10px 12px',
                border: '1px solid #e2e8f0'
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 4 }}>
                <span style={{ fontSize: '0.68rem', color: '#0284c7', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                  Origin ({fromCity})
                </span>
                <span style={{ display: 'flex', alignItems: 'center', gap: 3, fontSize: '0.88rem', fontWeight: 800, color: '#0f172a' }}>
                  <Thermometer size={14} color="#0284c7" />
                  {data.fromWeather?.tempCelsius}°C
                </span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: '0.78rem', color: '#475569', fontWeight: 500 }}>
                <Wind size={13} color="#94a3b8" />
                <span>{data.fromWeather?.condition || 'Clear'} · Wind: {data.fromWeather?.windSpeedKmh} km/h</span>
              </div>
            </div>

            {/* Destination Card */}
            <div
              style={{
                background: '#f8fafc',
                borderRadius: 8,
                padding: '10px 12px',
                border: '1px solid #e2e8f0'
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 4 }}>
                <span style={{ fontSize: '0.68rem', color: '#16a34a', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                  Destination ({toCity})
                </span>
                <span style={{ display: 'flex', alignItems: 'center', gap: 3, fontSize: '0.88rem', fontWeight: 800, color: '#0f172a' }}>
                  <Thermometer size={14} color="#16a34a" />
                  {data.toWeather?.tempCelsius}°C
                </span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: '0.78rem', color: '#475569', fontWeight: 500 }}>
                <Wind size={13} color="#94a3b8" />
                <span>{data.toWeather?.condition || 'Clear'} · Wind: {data.toWeather?.windSpeedKmh} km/h</span>
              </div>
            </div>
          </div>

          {/* Road Transit Condition */}
          {data.advice && (
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                flexWrap: 'wrap',
                gap: 8,
                fontSize: '0.76rem',
                color: '#334155',
                background: '#f8fafc',
                padding: '8px 12px',
                borderRadius: 8,
                border: '1px solid #e2e8f0',
                marginBottom: weatherNote ? 10 : 0
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <Navigation size={14} color="#0284c7" />
                <span style={{ fontWeight: 600 }}>{data.advice}</span>
              </div>
              {data.recommendedBufferMinutes > 0 && (
                <span
                  style={{
                    background: '#fef3c7',
                    color: '#92400e',
                    padding: '2px 8px',
                    borderRadius: 4,
                    fontSize: '0.7rem',
                    fontWeight: 700
                  }}
                >
                  +{data.recommendedBufferMinutes} min buffer recommended
                </span>
              )}
            </div>
          )}
        </>
      ) : (
        <div style={{ fontSize: '0.78rem', color: '#64748b', padding: '6px 0', display: 'flex', alignItems: 'center', gap: 6 }}>
          <Info size={14} />
          {loading ? 'Fetching route live weather telemetry...' : (weatherNote || 'Standard coastal weather conditions reported.')}
        </div>
      )}

      {/* AI Cold-Chain Advisory Pill */}
      {weatherNote && (
        <div
          style={{
            background: 'linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%)',
            border: '1px solid #bae6fd',
            borderRadius: 8,
            padding: '8px 12px',
            fontSize: '0.76rem',
            color: '#0369a1',
            display: 'flex',
            alignItems: 'center',
            gap: 8
          }}
        >
          <Snowflake size={15} color="#0284c7" style={{ flexShrink: 0 }} />
          <div>
            <strong style={{ color: '#0c4a6e', marginRight: 4 }}>AI Cold-Chain Advisory:</strong>
            <span>{weatherNote}</span>
          </div>
        </div>
      )}
    </div>
  );
};
