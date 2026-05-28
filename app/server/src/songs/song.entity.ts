import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToMany,
} from 'typeorm';
import { Playlist } from '../playlists/playlist.entity';

@Entity('songs')
export class Song {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  title: string;

  @Column()
  artist: string;

  @Column({ nullable: true })
  album: string;

  @Column({ nullable: true })
  genre: string;

  @Column({ type: 'int', nullable: true })
  durationSeconds: number;

  @CreateDateColumn()
  createdAt: Date;

  @ManyToMany(() => Playlist, (playlist) => playlist.songs)
  playlists: Playlist[];
}
