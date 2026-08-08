import { Module } from '@nestjs/common';
import { ImagesService } from './images.service';
import { AdminImagesController } from './admin-images.controller';
import { SharpImageProcessor } from './sharp-image.processor';
import { InMemoryImageStorage, SupabaseImageStorage } from './supabase-image.storage';
import { IMAGE_PROCESSOR, IMAGE_STORAGE } from './image.ports';

/**
 * WHICH STORAGE, AND THE ONE RULE THAT MATTERS.
 *
 * Supabase when credentials are present; the in-memory one otherwise — but
 * **never in production**, where a missing credential throws at boot instead.
 *
 * The failure this prevents is the expensive one. A production API that
 * quietly fell back to a Map would accept every upload, return every URL, and
 * store nothing: the admin sees success, the database grows rows, and every
 * venue renders an empty state indistinguishable from a venue that simply has
 * no photos yet. Nobody would find it until a restaurant asked where their
 * pictures went.
 *
 * So the fallback is loud about being a fallback, and impossible where it
 * would be a lie. Same shape as the OTP delivery rule — a stub must not reach
 * a production build path.
 */
const storageProvider = {
  provide: IMAGE_STORAGE,
  useFactory: () => {
    const configured = Boolean(process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_KEY);

    if (!configured && process.env.NODE_ENV === 'production') {
      throw new Error(
        'SUPABASE_URL and SUPABASE_SERVICE_KEY are required in production. ' +
          'Refusing to start with in-memory image storage: uploads would report ' +
          'success and store nothing.',
      );
    }

    return configured
      ? SupabaseImageStorage.fromEnv(process.env)
      : new InMemoryImageStorage();
  },
};

@Module({
  providers: [
    ImagesService,
    storageProvider,
    { provide: IMAGE_PROCESSOR, useClass: SharpImageProcessor },
  ],
  controllers: [AdminImagesController],
  exports: [ImagesService],
})
export class ImagesModule {}
