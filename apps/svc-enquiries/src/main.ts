import { NestFactory } from "@nestjs/core";
import { AppModule } from "./app.module";

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    logger: ["error", "warn", "log"],
  });

  app.enableCors({ origin: "*" });

  const port = parseInt(process.env.PORT || "8080", 10);
  await app.listen(port, "0.0.0.0");
  // eslint-disable-next-line no-console
  console.log(`svc-enquiries listening on 0.0.0.0:${port}`);
}

bootstrap().catch((e) => {
  // eslint-disable-next-line no-console
  console.error("Fatal bootstrap error", e);
  process.exit(1);
});
