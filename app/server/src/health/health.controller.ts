import { Controller, Get, HttpCode } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';

@Controller('health')
export class HealthController {
  constructor(@InjectDataSource() private readonly dataSource: DataSource) {}

  @Get('liveness')
  @HttpCode(200)
  liveness() {
    return { status: 'alive' };
  }

  @Get('readiness')
  async readiness() {
    const connected = this.dataSource.isInitialized;
    return {
      status: connected ? 'ready' : 'not_ready',
      checks: { database: connected },
    };
  }
}
