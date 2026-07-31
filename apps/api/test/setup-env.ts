/**
 * Jest does not read .env the way the Nest/Prisma CLIs do. The e2e suite needs
 * DIRECT_URL and DATABASE_URL present before PrismaClient is constructed, so
 * load them here via setupFiles (which runs before the test module).
 */
import { config } from "dotenv";
import { resolve } from "path";

config({ path: resolve(__dirname, "..", ".env") });

if (!process.env.DATABASE_URL && !process.env.DIRECT_URL) {
  throw new Error(
    "No DATABASE_URL/DIRECT_URL. Fill apps/api/.env with your Supabase " +
      "password before running the e2e suite.",
  );
}