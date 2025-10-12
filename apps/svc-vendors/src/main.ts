import "reflect-metadata";
import { Logger } from "@nestjs/common";
import { NestFactory } from "@nestjs/core";
import { AppModule } from "./app.module";
import { PrismaService } from "./prisma/prisma.service";

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    bufferLogs: true
  });

  app.enableShutdownHooks();

  const prismaService = app.get(PrismaService);
  await prismaService.enableShutdownHooks(app);

  const port = Number(process.env.PORT ?? 3000);

  await app.listen(port);
  Logger.log(`Vendor service listening on port ${port}`, "Bootstrap");
}

bootstrap().catch((error) => {
  Logger.error("Failed to bootstrap vendor service", error);
  process.exit(1);
});
