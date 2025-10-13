import type { EnquiryStatus } from "@prisma/client";
import { IsEnum, IsOptional, IsString } from "class-validator";

export class EnquiryQueryDto {
  @IsOptional()
  @IsString()
  vendorId?: string;

  @IsOptional()
  @IsEnum(["NEW", "QUOTE_SENT", "MEETING_SCHEDULED", "CONTRACT_SIGNED", "WON"], {
    message: "status must be a valid enquiry status"
  })
  status?: EnquiryStatus;
}
