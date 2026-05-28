import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ServeStaticModule } from '@nestjs/serve-static';
import { join } from 'path';
import { Song } from './songs/song.entity';
import { Playlist } from './playlists/playlist.entity';
import { SongsModule } from './songs/songs.module';
import { PlaylistsModule } from './playlists/playlists.module';
import { HealthController } from './health/health.controller';
import { SeedModule } from './seed/seed.module';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: process.env.DB_HOST ?? 'localhost',
      port: parseInt(process.env.DB_PORT ?? '5432', 10),
      username: process.env.DB_USER ?? 'postgres',
      password: process.env.DB_PASSWORD ?? '',
      database: process.env.DB_NAME ?? 'groove',
      entities: [Song, Playlist],
      synchronize: true,
      retryAttempts: 5,
      retryDelay: 3000,
      logging: process.env.NODE_ENV === 'development' ? ['query', 'error'] : ['error'],
    }),
    ServeStaticModule.forRoot({
      rootPath: join(__dirname, '..', 'public'),
      exclude: ['/health*', '/api/*'],
      serveStaticOptions: { index: false },
    }),
    SongsModule,
    PlaylistsModule,
    SeedModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
