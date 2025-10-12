import { Module } from "@nestjs/common";
import { HealthModule } from "./health/health.module";
import { PrismaModule } from "./prisma/prisma.module";
import { AvailabilityModule } from "./availability/availability.module";

@Module({
  imports: [PrismaModule, HealthModule, AvailabilityModule]
})
export class AppModule {}
