import { Injectable } from '@nestjs/common';

@Injectable()
export class HealthService {
  async checkDb(): Promise<boolean> {
    try {
      // TODO: подключить конкретную БД; временно просто имитируем ping
      return true;
    } catch {
      return false;
    }
  }
}
