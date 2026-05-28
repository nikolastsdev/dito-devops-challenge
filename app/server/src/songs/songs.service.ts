import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, ILike } from 'typeorm';
import { Song } from './song.entity';

@Injectable()
export class SongsService {
  constructor(
    @InjectRepository(Song)
    private readonly repo: Repository<Song>,
  ) {}

  findAll(search?: string): Promise<Song[]> {
    if (search) {
      return this.repo.find({
        where: [
          { title: ILike(`%${search}%`) },
          { artist: ILike(`%${search}%`) },
          { album: ILike(`%${search}%`) },
        ],
        order: { artist: 'ASC', title: 'ASC' },
      });
    }
    return this.repo.find({ order: { artist: 'ASC', title: 'ASC' } });
  }

  async findOne(id: string): Promise<Song> {
    const song = await this.repo.findOne({ where: { id } });
    if (!song) throw new NotFoundException(`Song ${id} not found`);
    return song;
  }

  create(data: Partial<Song>): Promise<Song> {
    const song = this.repo.create(data);
    return this.repo.save(song);
  }

  count(): Promise<number> {
    return this.repo.count();
  }

  saveMany(songs: Partial<Song>[]): Promise<Song[]> {
    return this.repo.save(songs.map((s) => this.repo.create(s)));
  }
}
