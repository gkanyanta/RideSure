-- Remove NRC documents from existing data (if any)
DELETE FROM "rider_documents" WHERE "type" = 'NRC';

-- AlterEnum: remove NRC, add bike photo types
ALTER TYPE "DocumentType" RENAME TO "DocumentType_old";
CREATE TYPE "DocumentType" AS ENUM ('SELFIE', 'RIDER_LICENCE', 'INSURANCE_CERTIFICATE', 'BIKE_FRONT', 'BIKE_BACK', 'BIKE_LEFT', 'BIKE_RIGHT');
ALTER TABLE "rider_documents" ALTER COLUMN "type" TYPE "DocumentType" USING ("type"::text::"DocumentType");
DROP TYPE "DocumentType_old";

-- Add fileData column for storing files in DB
ALTER TABLE "rider_documents" ADD COLUMN "fileData" BYTEA;
