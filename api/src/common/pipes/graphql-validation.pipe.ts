import {
  ArgumentMetadata,
  BadRequestException,
  Injectable,
  PipeTransform,
} from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validate, ValidationError } from 'class-validator';

function formatValidationErrors(errors: ValidationError[]): string {
  const messages: string[] = [];
  for (const error of errors) {
    if (error.constraints) {
      messages.push(...Object.values(error.constraints));
      continue;
    }
    if (error.children?.length) {
      messages.push(...formatValidationErrors(error.children).split('; '));
    }
  }
  return messages.filter(Boolean).join('; ');
}

/** Validates GraphQL @InputType() / @ArgsType() classes with class-validator. */
@Injectable()
export class GraphqlValidationPipe implements PipeTransform {
  async transform(value: unknown, metadata: ArgumentMetadata) {
    if (!metadata.metatype || metadata.type === 'custom') {
      return value;
    }
    const gqlClassType = Reflect.getMetadata(
      'graphql:class_type',
      metadata.metatype,
    );
    if (!gqlClassType) {
      return value;
    }

    const instance = plainToInstance(metadata.metatype, value);
    const errors = await validate(instance as object, {
      whitelist: true,
      forbidNonWhitelisted: true,
    });
    if (errors.length > 0) {
      const message = formatValidationErrors(errors);
      throw new BadRequestException(message || 'Invalid request input.');
    }
    return instance;
  }
}
