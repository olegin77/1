import { Module } from "@nestjs/common";
import { AvailabilityController } from "./availability.controller";
import { AvailabilityService } from "./availability.service";
import { AvailabilityEventsPublisher } from "../messaging/availability-events.publisher";

@Module({
  controllers: [AvailabilityController],
  providers: [AvailabilityService, AvailabilityEventsPublisher]
})
export class AvailabilityModule {}
