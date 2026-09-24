export const API_BASE_URL = 'http://localhost:5157';

export const formatErrorMessage = (err: any, fallback: string = 'An unexpected error occurred'): string => {
  if (!err) return fallback;
  if (typeof err === 'string') return err.trim() || fallback;

  // Handle HTTP status code messages (e.g. 403 Forbidden)
  const status = err.response?.status;
  const statusFallback = status === 403
    ? 'Access denied. You do not have permission for this action.'
    : status === 401
    ? 'Session expired. Please log in again.'
    : status === 404
    ? 'Requested item not found.'
    : fallback;

  const data = err.response?.data ?? err.data;
  if (!data) return (err.message && err.message.trim()) ? err.message : statusFallback;
  if (typeof data === 'string') return data.trim() || statusFallback;

  // ASP.NET ProblemDetails / Custom error response: { status, title, detail, timestamp, traceId }
  if (data.detail && typeof data.detail === 'string' && data.detail.trim()) return data.detail.trim();
  if (data.title && typeof data.title === 'string' && data.title.trim()) return data.title.trim();
  if (data.message && typeof data.message === 'string' && data.message.trim()) return data.message.trim();

  // Validation errors: { errors: { field: ["msg1", "msg2"] } }
  if (data.errors && typeof data.errors === 'object') {
    const list = Object.values(data.errors).flat().filter(Boolean);
    if (list.length > 0) return list.join(' ');
  }

  try {
    const serialized = JSON.stringify(data);
    return (serialized && serialized !== '{}') ? serialized : statusFallback;
  } catch {
    return statusFallback;
  }
};
