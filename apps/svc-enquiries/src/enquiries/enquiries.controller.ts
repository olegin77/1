import { Controller, Get } from "@nestjs/common";
import { EnquiriesService } from "./enquiries.service";

@Controller("enquiries")
export class EnquiriesController {
  constructor(private readonly enquiriesService: EnquiriesService) {}

  @Get()
  findAll() {
    return this.enquiriesService.findAll();
  }
}
