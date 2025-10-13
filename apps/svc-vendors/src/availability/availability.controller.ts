import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query
} from "@nestjs/common";
import type { VendorAvailability } from "@prisma/client";
import { AvailabilityService } from "./availability.service";
import { AvailabilityQueryDto } from "./dto/query-availability.dto";
import { CreateAvailabilityDto } from "./dto/create-availability.dto";
import { UpdateAvailabilityDto } from "./dto/update-availability.dto";

@Controller("availability")
export class AvailabilityController {
  constructor(private readonly availabilityService: AvailabilityService) {}

  @Post()
  create(
    @Body() dto: CreateAvailabilityDto
  ): Promise<VendorAvailability> {
    return this.availabilityService.create(dto);
  }

  @Get()
  findAll(
    @Query() query: AvailabilityQueryDto
  ): Promise<VendorAvailability[]> {
    return this.availabilityService.findAll(query);
  }

  @Get(":id")
  findOne(@Param("id") id: string): Promise<VendorAvailability> {
    return this.availabilityService.findOne(id);
  }

  @Patch(":id")
  update(
    @Param("id") id: string,
    @Body() dto: UpdateAvailabilityDto
  ): Promise<VendorAvailability> {
    return this.availabilityService.update(id, dto);
  }

  @Delete(":id")
  remove(@Param("id") id: string): Promise<VendorAvailability> {
    return this.availabilityService.remove(id);
  }
}
