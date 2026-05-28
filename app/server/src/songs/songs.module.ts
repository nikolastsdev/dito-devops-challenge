import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Song } from './song.entity';
import { SongsService } from './songs.service';
import { SongsController } from './songs.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Song])],
  providers: [SongsService],
  controllers: [SongsController],
  exports: [SongsService],
})
export class SongsModule {}
