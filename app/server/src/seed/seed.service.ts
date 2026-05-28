import { Injectable, OnApplicationBootstrap, Logger } from '@nestjs/common';
import { SongsService } from '../songs/songs.service';

const CATALOG = [
  { title: 'Bohemian Rhapsody', artist: 'Queen', album: 'A Night at the Opera', genre: 'Rock', durationSeconds: 354 },
  { title: "Don't Stop Me Now", artist: 'Queen', album: 'Jazz', genre: 'Rock', durationSeconds: 209 },
  { title: 'Hotel California', artist: 'Eagles', album: 'Hotel California', genre: 'Rock', durationSeconds: 391 },
  { title: 'Stairway to Heaven', artist: 'Led Zeppelin', album: 'Led Zeppelin IV', genre: 'Rock', durationSeconds: 482 },
  { title: 'Smells Like Teen Spirit', artist: 'Nirvana', album: 'Nevermind', genre: 'Grunge', durationSeconds: 301 },
  { title: 'Creep', artist: 'Radiohead', album: 'Pablo Honey', genre: 'Alternative', durationSeconds: 239 },
  { title: 'Numb', artist: 'Linkin Park', album: 'Meteora', genre: 'Nu-Metal', durationSeconds: 187 },
  { title: 'Superstition', artist: 'Stevie Wonder', album: 'Talking Book', genre: 'Soul', durationSeconds: 245 },
  { title: 'Billie Jean', artist: 'Michael Jackson', album: 'Thriller', genre: 'Pop', durationSeconds: 294 },
  { title: 'Thriller', artist: 'Michael Jackson', album: 'Thriller', genre: 'Pop', durationSeconds: 358 },
  { title: 'Purple Rain', artist: 'Prince', album: 'Purple Rain', genre: 'R&B', durationSeconds: 520 },
  { title: 'Lose Yourself', artist: 'Eminem', album: '8 Mile', genre: 'Hip-Hop', durationSeconds: 326 },
  { title: "God's Plan", artist: 'Drake', album: 'Scorpion', genre: 'Hip-Hop', durationSeconds: 198 },
  { title: 'Rolling in the Deep', artist: 'Adele', album: '21', genre: 'Soul/Pop', durationSeconds: 228 },
  { title: 'Blinding Lights', artist: 'The Weeknd', album: 'After Hours', genre: 'Synth-pop', durationSeconds: 200 },
  { title: 'Shape of You', artist: 'Ed Sheeran', album: '÷', genre: 'Pop', durationSeconds: 234 },
  { title: 'Yesterday', artist: 'The Beatles', album: 'Help!', genre: 'Rock/Pop', durationSeconds: 125 },
  { title: 'Hey Jude', artist: 'The Beatles', album: 'Single', genre: 'Rock/Pop', durationSeconds: 431 },
  { title: 'Dreams', artist: 'Fleetwood Mac', album: 'Rumours', genre: 'Rock', durationSeconds: 254 },
  { title: 'Africa', artist: 'Toto', album: 'Toto IV', genre: 'Rock', durationSeconds: 295 },
  { title: 'Garota de Ipanema', artist: 'João Gilberto', album: 'Getz/Gilberto', genre: 'Bossa Nova', durationSeconds: 320 },
  { title: 'Aquarela', artist: 'Toquinho', album: 'Aquarela', genre: 'MPB', durationSeconds: 194 },
];

@Injectable()
export class SeedService implements OnApplicationBootstrap {
  private readonly logger = new Logger(SeedService.name);

  constructor(private readonly songsService: SongsService) {}

  async onApplicationBootstrap() {
    const count = await this.songsService.count();
    if (count === 0) {
      await this.songsService.saveMany(CATALOG);
      this.logger.log(`Catalog seeded: ${CATALOG.length} songs`);
    }
  }
}
