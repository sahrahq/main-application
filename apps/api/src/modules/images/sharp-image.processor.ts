import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import sharp from 'sharp';
import {
  IMAGE_FORMAT,
  IMAGE_SIZES,
  ImageProcessor,
  ProcessedImage,
  ResizedImage,
} from './image.ports';

/**
 * RESIZE ON UPLOAD, NEVER ON DISPLAY (doc 10 §3b).
 *
 * The rule this implements is the whole reason the pipeline exists. A 4 MB
 * original scaled down by the client costs full egress on every single view
 * and janks the phone decoding it; the same photo as a 160px WebP is a few
 * kilobytes. On the free tier egress is the ceiling that binds long before
 * storage does, so this is a cost decision as much as a performance one.
 *
 * ── WHY IT RUNS IN-PROCESS RATHER THAN IN A QUEUE ────────────────────────
 *
 * Uploads are rare, manual, and done by us (doc 10 §3b — there is no
 * owner-facing surface yet). A BullMQ job would add a `processing` state the
 * admin has to poll, for a workload of a handful of images per venue done by
 * somebody sitting at a keyboard. `images.status` exists in the committed
 * schema and is set to `ready` on success, so the async version is a change of
 * caller rather than a change of shape when volume justifies it.
 */
@Injectable()
export class SharpImageProcessor implements ImageProcessor {
  private readonly logger = new Logger(SharpImageProcessor.name);

  async process(input: Buffer): Promise<ProcessedImage> {
    // `failOn: 'error'` — malformed input is refused rather than silently
    // half-decoded into a grey rectangle nobody notices until a diner sees it.
    const source = sharp(input, { failOn: 'error' });

    const meta = await source.metadata().catch(() => null);
    if (!meta?.width || !meta.height) {
      throw new BadRequestException({
        code: 'invalid_image',
        message: 'That file could not be read as an image.',
        message_ar: 'مش قادرين نقرا الملف ده كصورة.',
      });
    }

    // ORIENTATION IS BAKED IN, and forgetting it is the classic photo bug: a
    // phone writes the pixels landscape and an EXIF tag saying "rotate 90".
    // `sharp` does not apply that unless asked, so without `rotate()` every
    // portrait photo from an iPhone would be stored on its side — and the
    // width/height below would describe the wrong orientation, so the client's
    // reserved box would be wrong too.
    const upright = source.rotate();
    const uprightMeta = await upright.metadata();
    const width = uprightMeta.width ?? meta.width;
    const height = uprightMeta.height ?? meta.height;

    const renditions: ResizedImage[] = [];
    for (const size of IMAGE_SIZES) {
      const body = await upright
        .clone()
        .resize({
          width: size,
          // NO HEIGHT, and no crop. The aspect ratio is the photographer's
          // decision; cropping to a fixed box here would cut the top off a
          // tall dining room and there would be nothing left to recover it
          // from at display time. The client reserves a box from the stored
          // width/height and fits the image into it.
          withoutEnlargement: true,
          fit: 'inside',
        })
        .toFormat(IMAGE_FORMAT, { quality: 82 })
        .toBuffer();

      renditions.push({ size, body });
    }

    this.logger.log(
      `Processed ${width}x${height} → ${renditions
        .map((r) => `${r.size}:${Math.round(r.body.length / 1024)}kB`)
        .join(' ')}`,
    );

    return { width, height, renditions, original: input };
  }
}
