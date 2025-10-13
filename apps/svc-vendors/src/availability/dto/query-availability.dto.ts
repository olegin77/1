import { Transform } from "class-transformer";
import { IsDate, IsOptional, IsString } from "class-validator";

export class AvailabilityQueryDto {
  @IsOptional()
  @IsString()
  vendorId?: string;

  @IsOptional()
  @Transform(({ value }) => new Date(value))
  @IsDate()
  from?: Date;

  @IsOptional()
  @Transform(({ value }) => new Date(value))
  @IsDate()
  to?: Date;
}
