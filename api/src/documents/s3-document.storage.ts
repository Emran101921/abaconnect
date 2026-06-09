import {
  DeleteObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { Injectable, Logger } from '@nestjs/common';
import { Readable } from 'stream';

@Injectable()
export class S3DocumentStorage {
  private readonly logger = new Logger(S3DocumentStorage.name);
  private readonly client: S3Client | null;
  private readonly bucket: string | null;
  private readonly kmsKeyId: string | null;

  constructor() {
    this.bucket = process.env.AWS_S3_BUCKET?.trim() || null;
    this.kmsKeyId = process.env.AWS_KMS_KEY_ID?.trim() || null;
    this.client = this.bucket
      ? new S3Client({ region: process.env.AWS_REGION ?? 'us-east-1' })
      : null;
  }

  isEnabled(): boolean {
    return this.client != null && this.bucket != null;
  }

  requiresKmsInProduction(): boolean {
    return (
      (process.env.NODE_ENV === 'production' ||
        process.env.NODE_ENV === 'staging') &&
      this.isEnabled() &&
      !this.kmsKeyId
    );
  }

  async putObject(key: string, body: Buffer): Promise<void> {
    if (!this.client || !this.bucket) {
      throw new Error('S3 document storage is not configured');
    }
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: body,
        ServerSideEncryption: this.kmsKeyId ? 'aws:kms' : 'AES256',
        ...(this.kmsKeyId ? { SSEKMSKeyId: this.kmsKeyId } : {}),
      }),
    );
    this.logger.debug(`Stored document object ${key}`);
  }

  async getObjectBuffer(key: string): Promise<Buffer> {
    if (!this.client || !this.bucket) {
      throw new Error('S3 document storage is not configured');
    }
    const response = await this.client.send(
      new GetObjectCommand({ Bucket: this.bucket, Key: key }),
    );
    const stream = response.Body as Readable;
    const chunks: Buffer[] = [];
    for await (const chunk of stream) {
      chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    }
    return Buffer.concat(chunks);
  }

  async deleteObject(key: string): Promise<void> {
    if (!this.client || !this.bucket) {
      return;
    }
    await this.client.send(
      new DeleteObjectCommand({ Bucket: this.bucket, Key: key }),
    );
  }
}
