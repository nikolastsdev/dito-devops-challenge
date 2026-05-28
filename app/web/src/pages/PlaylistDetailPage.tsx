import { useEffect, useState, useCallback } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { api, Playlist, Song, formatDuration, timeAgo } from '../api/client';

export function PlaylistDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();

  const [playlist, setPlaylist] = useState<Playlist | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showAddModal, setShowAddModal] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [deleting, setDeleting] = useState(false);

  const load = useCallback(() => {
    if (!id) return;
    setLoading(true);
    api.playlists
      .get(id)
      .then(setPlaylist)
      .catch((e: Error) => setError(e.message))
      .finally(() => setLoading(false));
  }, [id]);

  useEffect(load, [load]);

  const handleRemoveSong = async (songId: string) => {
    if (!id) return;
    try {
      const updated = await api.playlists.removeSong(id, songId);
      setPlaylist(updated);
    } catch (e: any) {
      setError(e.message);
    }
  };

  const handleDelete = async () => {
    if (!id) return;
    setDeleting(true);
    try {
      await api.playlists.delete(id);
      navigate('/');
    } catch (e: any) {
      setError(e.message);
      setDeleting(false);
    }
  };

  const handleSongAdded = (updated: Playlist) => {
    setPlaylist(updated);
  };

  const totalDuration = playlist?.songs.reduce((acc, s) => acc + (s.durationSeconds ?? 0), 0) ?? 0;

  if (loading) {
    return (
      <div className="page">
        <Header />
        <main className="content">
          <div className="loading"><div className="spinner" /> Carregando…</div>
        </main>
      </div>
    );
  }

  if (!playlist) {
    return (
      <div className="page">
        <Header />
        <main className="content">
          <div className="error-msg">Playlist não encontrada.</div>
          <Link to="/" className="back-link">← Voltar</Link>
        </main>
      </div>
    );
  }

  return (
    <div className="page">
      <Header />
      <main className="content">
        <Link to="/" className="back-link">← Todas as playlists</Link>

        {error && <div className="error-msg">Erro: {error}</div>}

        <div className="detail-hero">
          <div className="detail-hero-icon">🎵</div>
          <div className="detail-hero-info">
            <div className="detail-hero-label">Playlist</div>
            <div className="detail-hero-name">{playlist.name}</div>
            {playlist.description && (
              <div className="detail-hero-desc">{playlist.description}</div>
            )}
            <div className="detail-hero-meta">
              <span>🎵 {playlist.songs.length} músicas</span>
              {totalDuration > 0 && (
                <span>⏱ {formatDuration(totalDuration)}</span>
              )}
              <span>📅 Criada {timeAgo(playlist.createdAt)}</span>
            </div>
          </div>
          <div className="detail-hero-actions">
            <button className="btn btn-accent" onClick={() => setShowAddModal(true)}>
              + Adicionar música
            </button>
            {!confirmDelete ? (
              <button className="btn btn-danger" onClick={() => setConfirmDelete(true)}>
                🗑 Deletar
              </button>
            ) : (
              <button
                className="btn btn-danger"
                onClick={handleDelete}
                disabled={deleting}
                style={{ background: 'var(--danger)', color: '#fff' }}
              >
                {deleting ? 'Deletando…' : 'Confirmar exclusão'}
              </button>
            )}
            {confirmDelete && (
              <button className="btn btn-ghost" onClick={() => setConfirmDelete(false)}>
                Cancelar
              </button>
            )}
          </div>
        </div>

        <div className="section-header">
          <span className="section-title">Músicas</span>
        </div>

        {playlist.songs.length === 0 ? (
          <div className="empty-state">
            <span className="empty-state-icon">🎧</span>
            <h3>Playlist vazia</h3>
            <p>Adicione músicas do catálogo para começar.</p>
            <br />
            <button className="btn btn-accent" onClick={() => setShowAddModal(true)}>
              + Adicionar música
            </button>
          </div>
        ) : (
          <table className="song-table">
            <thead>
              <tr>
                <th className="song-num">#</th>
                <th>Título</th>
                <th>Artista</th>
                <th>Álbum</th>
                <th>Gênero</th>
                <th className="song-duration">Duração</th>
                <th className="song-actions"></th>
              </tr>
            </thead>
            <tbody>
              {playlist.songs.map((song, i) => (
                <tr key={song.id}>
                  <td className="song-num">{i + 1}</td>
                  <td className="song-title">{song.title}</td>
                  <td className="song-artist">{song.artist}</td>
                  <td className="song-album">{song.album ?? '—'}</td>
                  <td className="song-genre">
                    {song.genre && <span className="genre-badge">{song.genre}</span>}
                  </td>
                  <td className="song-duration">
                    {song.durationSeconds ? formatDuration(song.durationSeconds) : '—'}
                  </td>
                  <td className="song-actions">
                    <button
                      className="btn-icon"
                      title="Remover da playlist"
                      onClick={() => handleRemoveSong(song.id)}
                    >
                      ×
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </main>

      {showAddModal && (
        <AddSongModal
          playlistId={id!}
          existingIds={playlist.songs.map((s) => s.id)}
          onClose={() => setShowAddModal(false)}
          onAdded={handleSongAdded}
        />
      )}
    </div>
  );
}

function Header() {
  return (
    <header className="app-header">
      <Link to="/" className="logo">
        <span className="logo-icon">🎵</span>
        Groove
      </Link>
    </header>
  );
}

function AddSongModal({
  playlistId,
  existingIds,
  onClose,
  onAdded,
}: {
  playlistId: string;
  existingIds: string[];
  onClose: () => void;
  onAdded: (p: Playlist) => void;
}) {
  const [songs, setSongs] = useState<Song[]>([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [adding, setAdding] = useState<string | null>(null);

  useEffect(() => {
    api.songs
      .list()
      .then(setSongs)
      .finally(() => setLoading(false));
  }, []);

  const filtered = songs.filter((s) => {
    const q = search.toLowerCase();
    return (
      s.title.toLowerCase().includes(q) ||
      s.artist.toLowerCase().includes(q) ||
      (s.album ?? '').toLowerCase().includes(q) ||
      (s.genre ?? '').toLowerCase().includes(q)
    );
  });

  const handleAdd = async (songId: string) => {
    setAdding(songId);
    try {
      const updated = await api.playlists.addSong(playlistId, songId);
      onAdded(updated);
    } finally {
      setAdding(null);
    }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" style={{ maxWidth: 540 }} onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <span className="modal-title">Adicionar música</span>
          <button className="modal-close" onClick={onClose}>×</button>
        </div>
        <div className="modal-body" style={{ padding: '1rem 1.5rem' }}>
          <div className="search-input-wrap">
            <span className="search-icon">🔍</span>
            <input
              className="form-input with-icon"
              placeholder="Buscar por título, artista, álbum…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              autoFocus
            />
          </div>

          {loading ? (
            <div className="loading"><div className="spinner" /></div>
          ) : filtered.length === 0 ? (
            <p style={{ color: 'var(--text-muted)', textAlign: 'center', padding: '2rem 0' }}>
              Nenhuma música encontrada.
            </p>
          ) : (
            <div className="song-list-modal">
              {filtered.map((song) => {
                const inPlaylist = existingIds.includes(song.id);
                return (
                  <div key={song.id} className="song-list-item">
                    <div className="song-list-item-info">
                      <div className="song-list-item-title">{song.title}</div>
                      <div className="song-list-item-sub">
                        {song.artist}
                        {song.album ? ` · ${song.album}` : ''}
                        {song.durationSeconds ? ` · ${formatDuration(song.durationSeconds)}` : ''}
                      </div>
                    </div>
                    {inPlaylist ? (
                      <span style={{ fontSize: '0.75rem', color: 'var(--accent)' }}>✓ Na playlist</span>
                    ) : (
                      <button
                        className="btn-icon btn-icon-add"
                        title="Adicionar à playlist"
                        disabled={adding === song.id}
                        onClick={() => handleAdd(song.id)}
                      >
                        {adding === song.id ? '…' : '+'}
                      </button>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>
        <div className="modal-footer">
          <button className="btn btn-ghost" onClick={onClose}>Fechar</button>
        </div>
      </div>
    </div>
  );
}
