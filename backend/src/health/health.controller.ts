import { Controller, Get } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';

@Controller('health')
export class HealthController {
  constructor(private db: DatabaseService) {}

  @Get()
  async check() {
    const result = await this.db.query('SELECT NOW()');
    return {
      status: 'ok',
      dbTime: result.rows[0],
    };
  }
}