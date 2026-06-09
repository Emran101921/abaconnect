import {
  ArgumentMetadata,
  BadRequestException,
  Injectable,
  PipeTransform,
} from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';

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
      throw new BadRequestException(errors);
    }
    return instance;
  }
}
