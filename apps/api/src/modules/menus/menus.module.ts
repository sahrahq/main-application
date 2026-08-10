import { Module } from '@nestjs/common';
import { MenusController } from './menus.controller';
import { MenusService } from './menus.service';
import { ImagesModule } from '../images/images.module';
import { LiveRestaurantModule } from '../restaurants/live-restaurant.module';

@Module({
  imports: [ImagesModule, LiveRestaurantModule],
  controllers: [MenusController],
  providers: [MenusService],
})
export class MenusModule {}
