import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    logger: ['error', 'warn', 'log'],
  });
  app.enableCors();
  const port = parseInt(process.env.PORT ?? '8080', 10);
  await app.listen(port);
  console.log(`[groove] listening on port ${port} (${process.env.NODE_ENV ?? 'development'})`);
}
bootstrap();
