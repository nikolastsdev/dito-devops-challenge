import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Playlist } from './playlist.entity';
import { SongsService } from '../songs/songs.service';

@Injectable()
export class PlaylistsService {
  constructor(
    @InjectRepository(Playlist)
    private readonly repo: Repository<Playlist>,
    private readonly songsService: SongsService,
  ) {}

  findAll(): Promise<Playlist[]> {
    return this.repo.find({ order: { createdAt: 'DESC' } });
  }

  async findOne(id: string): Promise<Playlist> {
    const playlist = await this.repo.findOne({ where: { id } });
    if (!playlist) throw new NotFoundException(`Playlist ${id} not found`);
    return playlist;
  }

  create(data: { name: string; description?: string }): Promise<Playlist> {
    const playlist = this.repo.create({ ...data, songs: [] });
    return this.repo.save(playlist);
  }

  async delete(id: string): Promise<void> {
    const playlist = await this.findOne(id);
    await this.repo.remove(playlist);
  }

  async addSong(playlistId: string, songId: string): Promise<Playlist> {
    const playlist = await this.findOne(playlistId);
    const song = await this.songsService.findOne(songId);
    const alreadyAdded = playlist.songs.some((s) => s.id === songId);
    if (!alreadyAdded) {
      playlist.songs = [...playlist.songs, song];
      await this.repo.save(playlist);
    }
    return this.findOne(playlistId);
  }

  async removeSong(playlistId: string, songId: string): Promise<Playlist> {
    const playlist = await this.findOne(playlistId);
    playlist.songs = playlist.songs.filter((s) => s.id !== songId);
    await this.repo.save(playlist);
    return this.findOne(playlistId);
  }
}
