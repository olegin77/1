import { Transform } from "class-transformer";
import {
  IsBoolean,
  IsDate,
  IsOptional,
  IsString,
  MaxLength
} from "class-validator";

export class CreateAvailabilityDto {
  @IsString()
  vendorId!: string;

  @Transform(({ value }) => new Date(value))
  @IsDate()
  eventDate!: Date;

  @IsOptional()
  @IsBoolean()
  isAvailable?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(10_000)
  notes?: string;
}
