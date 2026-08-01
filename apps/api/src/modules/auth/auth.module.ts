import { Module } from "@nestjs/common";
import { JwtModule } from "@nestjs/jwt";
import { PassportModule } from "@nestjs/passport";
import { AuthService } from "./auth.service";
import { TokenService } from "./token.service";
import { AuthController } from "./auth.controller";
import { JwtStrategy } from "../../shared/auth/jwt.strategy";
import { OtpService } from "./otp/otp.service";
import { otpProviders } from "./otp/otp.providers";

@Module({
  imports: [PassportModule.register({ defaultStrategy: "jwt" }), JwtModule.register({})],
  providers: [AuthService, TokenService, JwtStrategy, OtpService, ...otpProviders],
  controllers: [AuthController],
  exports: [AuthService, TokenService, OtpService],
})
export class AuthModule {}