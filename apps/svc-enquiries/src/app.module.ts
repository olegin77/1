import { Module } from "@nestjs/common";
import { HealthModule } from "./health/health.module";
import { PrismaModule } from "./prisma/prisma.module";
import { EnquiriesModule } from "./enquiries/enquiries.module";

@Module({
  imports: [PrismaModule, HealthModule, EnquiriesModule]
})
export class AppModule {}
