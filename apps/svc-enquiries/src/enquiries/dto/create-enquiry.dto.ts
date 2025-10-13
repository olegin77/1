import { Type } from "class-transformer";
import {
  IsDate,
  IsEmail,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min
} from "class-validator";

export class CreateEnquiryDto {
  @IsString()
  @MaxLength(64)
  vendorId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  coupleName?: string;

  @IsOptional()
  @IsEmail()
  contactEmail?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  contactPhone?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  budget?: number;

  @IsOptional()
  @Type(() => Date)
  @IsDate()
  eventDate?: Date;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  source?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;
}
