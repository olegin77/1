import { Controller, Get } from '@nestjs/common';
import { HealthService } from './health.service';

@Controller('health')
export class HealthController {
  constructor(private readonly svc: HealthService) {}

  @Get()
  async ok() {
    const db = await this.svc.checkDb();
    return { status: 'ok', db };
  }
}
