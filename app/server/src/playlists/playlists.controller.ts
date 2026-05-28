import {
  Controller,
  Get,
  Post,
  Delete,
  Param,
  Body,
  HttpCode,
} from '@nestjs/common';
import { PlaylistsService } from './playlists.service';

@Controller('api/playlists')
export class PlaylistsController {
  constructor(private readonly playlistsService: PlaylistsService) {}

  @Get()
  findAll() {
    return this.playlistsService.findAll();
  }

  @Post()
  create(@Body() body: { name: string; description?: string }) {
    return this.playlistsService.create(body);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.playlistsService.findOne(id);
  }

  @Delete(':id')
  @HttpCode(204)
  delete(@Param('id') id: string) {
    return this.playlistsService.delete(id);
  }

  @Post(':id/songs')
  addSong(@Param('id') id: string, @Body() body: { songId: string }) {
    return this.playlistsService.addSong(id, body.songId);
  }

  @Delete(':id/songs/:songId')
  @HttpCode(200)
  removeSong(@Param('id') id: string, @Param('songId') songId: string) {
    return this.playlistsService.removeSong(id, songId);
  }
}
