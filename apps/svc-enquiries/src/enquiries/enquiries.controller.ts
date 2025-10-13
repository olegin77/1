import { Body, Controller, Get, Param, Patch, Post, Query } from "@nestjs/common";
import { EnquiriesService } from "./enquiries.service";
import { CreateEnquiryDto } from "./dto/create-enquiry.dto";
import { EnquiryQueryDto } from "./dto/enquiry-query.dto";
import { UpdateEnquiryDto } from "./dto/update-enquiry.dto";
import { UpdateEnquiryStatusDto } from "./dto/update-enquiry-status.dto";

@Controller("enquiries")
export class EnquiriesController {
  constructor(private readonly enquiriesService: EnquiriesService) {}

  @Post()
  create(@Body() dto: CreateEnquiryDto) {
    return this.enquiriesService.create(dto);
  }

  @Get()
  findAll(@Query() query: EnquiryQueryDto) {
    return this.enquiriesService.findAll(query);
  }

  @Get(":id")
  findOne(@Param("id") id: string) {
    return this.enquiriesService.findOne(id);
  }

  @Patch(":id")
  update(@Param("id") id: string, @Body() dto: UpdateEnquiryDto) {
    return this.enquiriesService.update(id, dto);
  }

  @Patch(":id/status")
  updateStatus(
    @Param("id") id: string,
    @Body() dto: UpdateEnquiryStatusDto
  ) {
    return this.enquiriesService.updateStatus(id, dto);
  }
}
