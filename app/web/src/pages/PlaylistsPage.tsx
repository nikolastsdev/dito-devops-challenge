import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, Playlist, timeAgo } from '../api/client';

const PLAYLIST_ICONS = ['🎵', '🎸', '🎹', '🥁', '🎷', '🎺', '🎻', '🎤', '🎧', '🎼'];

function pickIcon(name: string): string {
  let hash = 0;
  for (let i = 0; i < name.length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash);
  return PLAYLIST_ICONS[Math.abs(hash) % PLAYLIST_ICONS.length];
}

export function PlaylistsPage() {
  const [playlists, setPlaylists] = useState<Playlist[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showCreate, setShowCreate] = useState(false);
  const [creating, setCreating] = useState(false);
  const [form, setForm] = useState({ name: '', description: '' });

  const load = () => {
    setLoading(true);
    api.playlists
      .list()
      .then(setPlaylists)
      .catch((e: Error) => setError(e.message))
      .finally(() => setLoading(false));
  };

  useEffect(load, []);

  const handleCreate = async () => {
    if (!form.name.trim()) return;
    setCreating(true);
    try {
      await api.playlists.create({ name: form.name.trim(), description: form.description.trim() || undefined });
      setForm({ name: '', description: '' });
      setShowCreate(false);
      load();
    } catch (e: any) {
      setError(e.message);
    } finally {
      setCreating(false);
    }
  };

  return (
    <div className="page">
      <header className="app-header">
        <a href="/" className="logo">
          <span className="logo-icon">🎵</span>
          Groove
        </a>
        <div className="header-actions">
          <button className="btn btn-primary" onClick={() => setShowCreate(true)}>
            + Nova playlist
          </button>
        </div>
      </header>

      <main className="content">
        <div className="page-header">
          <div>
            <h1 className="page-title">Suas playlists</h1>
            <p className="page-subtitle">
              {loading ? '…' : `${playlists.length} playlist${playlists.length !== 1 ? 's' : ''}`}
            </p>
          </div>
        </div>

        {error && <div className="error-msg">Erro: {error}</div>}

        {loading ? (
          <div className="loading">
            <div className="spinner" />
            Carregando…
          </div>
        ) : playlists.length === 0 ? (
          <div className="empty-state">
            <span className="empty-state-icon">🎼</span>
            <h3>Nenhuma playlist ainda</h3>
            <p>Crie sua primeira playlist e comece a montar sua coleção.</p>
            <br />
            <button className="btn btn-primary" onClick={() => setShowCreate(true)}>
              + Criar playlist
            </button>
          </div>
        ) : (
          <div className="playlist-grid">
            {playlists.map((p) => (
              <Link key={p.id} to={`/playlists/${p.id}`} className="playlist-card">
                <span className="playlist-card-icon">{pickIcon(p.name)}</span>
                <div className="playlist-card-name">{p.name}</div>
                <div className="playlist-card-desc">{p.description || 'Sem descrição'}</div>
                <div className="playlist-card-meta">
                  <span>🎵 {p.songs.length} {p.songs.length === 1 ? 'música' : 'músicas'}</span>
                  <span>🕐 {timeAgo(p.createdAt)}</span>
                </div>
              </Link>
            ))}
          </div>
        )}
      </main>

      {showCreate && (
        <div className="modal-overlay" onClick={() => setShowCreate(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <span className="modal-title">Nova playlist</span>
              <button className="modal-close" onClick={() => setShowCreate(false)}>×</button>
            </div>
            <div className="modal-body">
              <div className="form-group">
                <label className="form-label">Nome *</label>
                <input
                  className="form-input"
                  placeholder="Ex: Rock dos anos 90"
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                  onKeyDown={(e) => e.key === 'Enter' && handleCreate()}
                  autoFocus
                />
              </div>
              <div className="form-group">
                <label className="form-label">Descrição</label>
                <textarea
                  className="form-textarea"
                  placeholder="Uma descrição opcional…"
                  value={form.description}
                  onChange={(e) => setForm({ ...form, description: e.target.value })}
                />
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-ghost" onClick={() => setShowCreate(false)}>
                Cancelar
              </button>
              <button
                className="btn btn-primary"
                onClick={handleCreate}
                disabled={creating || !form.name.trim()}
              >
                {creating ? 'Criando…' : 'Criar playlist'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
