import { Module } from '@nestjs/common';
import { SeedService } from './seed.service';
import { SongsModule } from '../songs/songs.module';

@Module({
  imports: [SongsModule],
  providers: [SeedService],
})
export class SeedModule {}
