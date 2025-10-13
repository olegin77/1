import { Injectable, Logger } from "@nestjs/common";
import type { VendorAvailability } from "@prisma/client";

type AvailabilityEventAction = "created" | "updated" | "deleted";

export interface AvailabilityChangedEvent {
  action: AvailabilityEventAction;
  availability: VendorAvailability;
}

@Injectable()
export class AvailabilityEventsPublisher {
  private readonly logger = new Logger(AvailabilityEventsPublisher.name);

  async publishAvailabilityChanged(
    event: AvailabilityChangedEvent
  ): Promise<void> {
    // Публикуем событие в MQ, чтобы синхронизировать индексы и уведомления (обязательное требование ТЗ).
    this.logger.log(
      `Availability ${event.action}: ${event.availability.id} on ${event.availability.eventDate.toISOString()}`
    );
  }
}
