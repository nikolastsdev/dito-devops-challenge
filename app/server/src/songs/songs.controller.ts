import { Controller, Get, Post, Body, Query } from '@nestjs/common';
import { SongsService } from './songs.service';
import { Song } from './song.entity';

@Controller('api/songs')
export class SongsController {
  constructor(private readonly songsService: SongsService) {}

  @Get()
  findAll(@Query('search') search?: string) {
    return this.songsService.findAll(search);
  }

  @Post()
  create(
    @Body()
    body: Pick<Song, 'title' | 'artist' | 'album' | 'genre' | 'durationSeconds'>,
  ) {
    return this.songsService.create(body);
  }
}
