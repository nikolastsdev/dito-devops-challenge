import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToMany,
  JoinTable,
} from 'typeorm';
import { Song } from '../songs/song.entity';

@Entity('playlists')
export class Playlist {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column({ nullable: true })
  description: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @ManyToMany(() => Song, (song) => song.playlists, { eager: true })
  @JoinTable({
    name: 'playlist_songs',
    joinColumn: { name: 'playlist_id', referencedColumnName: 'id' },
    inverseJoinColumn: { name: 'song_id', referencedColumnName: 'id' },
  })
  songs: Song[];
}
