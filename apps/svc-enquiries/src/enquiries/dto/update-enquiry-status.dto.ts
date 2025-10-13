import type { EnquiryStatus } from "@prisma/client";
import { IsEnum } from "class-validator";

export class UpdateEnquiryStatusDto {
  @IsEnum(["NEW", "QUOTE_SENT", "MEETING_SCHEDULED", "CONTRACT_SIGNED", "WON"], {
    message: "status must be a valid enquiry status"
  })
  status!: EnquiryStatus;
}
