import { Routes, Route, Navigate } from 'react-router-dom';
import { PlaylistsPage } from './pages/PlaylistsPage';
import { PlaylistDetailPage } from './pages/PlaylistDetailPage';

export function App() {
  return (
    <Routes>
      <Route path="/" element={<PlaylistsPage />} />
      <Route path="/playlists/:id" element={<PlaylistDetailPage />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
