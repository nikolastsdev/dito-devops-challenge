export interface Song {
  id: string;
  title: string;
  artist: string;
  album: string;
  genre: string;
  durationSeconds: number;
  createdAt: string;
}

export interface Playlist {
  id: string;
  name: string;
  description: string;
  songs: Song[];
  createdAt: string;
  updatedAt: string;
}

async function request<T>(url: string, init?: RequestInit): Promise<T> {
  const res = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...init?.headers },
    ...init,
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ message: res.statusText }));
    throw new Error(err.message ?? `HTTP ${res.status}`);
  }
  if (res.status === 204) return undefined as T;
  return res.json();
}

export const api = {
  songs: {
    list: (search?: string) =>
      request<Song[]>(`/api/songs${search ? `?search=${encodeURIComponent(search)}` : ''}`),
    create: (data: Partial<Song>) =>
      request<Song>('/api/songs', { method: 'POST', body: JSON.stringify(data) }),
  },
  playlists: {
    list: () => request<Playlist[]>('/api/playlists'),
    get: (id: string) => request<Playlist>(`/api/playlists/${id}`),
    create: (data: { name: string; description?: string }) =>
      request<Playlist>('/api/playlists', { method: 'POST', body: JSON.stringify(data) }),
    delete: (id: string) =>
      request<void>(`/api/playlists/${id}`, { method: 'DELETE' }),
    addSong: (id: string, songId: string) =>
      request<Playlist>(`/api/playlists/${id}/songs`, {
        method: 'POST',
        body: JSON.stringify({ songId }),
      }),
    removeSong: (id: string, songId: string) =>
      request<Playlist>(`/api/playlists/${id}/songs/${songId}`, { method: 'DELETE' }),
  },
};

export function formatDuration(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${s.toString().padStart(2, '0')}`;
}

export function timeAgo(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 60) return `${mins}min atrás`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h atrás`;
  const days = Math.floor(hours / 24);
  if (days < 30) return `${days}d atrás`;
  return new Date(dateStr).toLocaleDateString('pt-BR');
}
