import { Injectable, Logger } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import { v4 as uuid } from 'uuid';

export interface StorageProvider {
  save(file: Express.Multer.File, folder: string): Promise<string>;
  getPath(filePath: string): string;
  delete(filePath: string): Promise<void>;
}

/** Local filesystem storage for development. Replace with S3-compatible provider in production. */
@Injectable()
export class StorageService implements StorageProvider {
  private readonly logger = new Logger(StorageService.name);
  private readonly uploadDir: string;

  constructor() {
    this.uploadDir = path.resolve(process.env.UPLOAD_DIR || './uploads');
    if (!fs.existsSync(this.uploadDir)) {
      fs.mkdirSync(this.uploadDir, { recursive: true });
    }
  }

  async save(file: Express.Multer.File, folder: string): Promise<string> {
    const dir = path.join(this.uploadDir, folder);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    const ext = path.extname(file.originalname);
    const filename = `${uuid()}${ext}`;
    const filePath = path.join(dir, filename);

    fs.writeFileSync(filePath, file.buffer);
    this.logger.log(`Saved file: ${folder}/${filename}`);

    return `${folder}/${filename}`;
  }

  getPath(filePath: string): string {
    return path.join(this.uploadDir, filePath);
  }

  async delete(filePath: string): Promise<void> {
    const fullPath = this.getPath(filePath);
    if (fs.existsSync(fullPath)) {
      fs.unlinkSync(fullPath);
    }
  }
}
