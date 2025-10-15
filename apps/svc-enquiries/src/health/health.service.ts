import { Injectable } from '@nestjs/common';

@Injectable()
export class HealthService {
  async check() {
    // TODO: wire real DB ping when Prisma present
    const db = false;
    return { status: 'ok', db };
  }
}
