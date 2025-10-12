import { Injectable, NotFoundException } from "@nestjs/common";
import type { Prisma, VendorAvailability } from "@prisma/client";
import { AvailabilityEventsPublisher } from "../messaging/availability-events.publisher";
import { PrismaService } from "../prisma/prisma.service";
import { AvailabilityQueryDto } from "./dto/query-availability.dto";
import { CreateAvailabilityDto } from "./dto/create-availability.dto";
import { UpdateAvailabilityDto } from "./dto/update-availability.dto";

@Injectable()
export class AvailabilityService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly eventsPublisher: AvailabilityEventsPublisher
  ) {}

  async create(dto: CreateAvailabilityDto): Promise<VendorAvailability> {
    const availability = await this.prisma.vendorAvailability.create({
      data: {
        vendorId: dto.vendorId,
        eventDate: dto.eventDate,
        isAvailable: dto.isAvailable ?? true,
        notes: dto.notes ?? null
      }
    });

    await this.eventsPublisher.publishAvailabilityChanged({
      action: "created",
      availability
    });

    return availability;
  }

  async findAll(query: AvailabilityQueryDto): Promise<VendorAvailability[]> {
    const where: Prisma.VendorAvailabilityWhereInput = {};

    if (query.vendorId) {
      where.vendorId = query.vendorId;
    }

    if (query.from || query.to) {
      where.eventDate = {
        ...(query.from ? { gte: query.from } : {}),
        ...(query.to ? { lte: query.to } : {})
      };
    }

    return this.prisma.vendorAvailability.findMany({
      where,
      orderBy: { eventDate: "asc" }
    });
  }

  async findOne(id: string): Promise<VendorAvailability> {
    const availability = await this.prisma.vendorAvailability.findUnique({
      where: { id }
    });

    if (!availability) {
      throw new NotFoundException(`Availability ${id} not found`);
    }

    return availability;
  }

  async update(
    id: string,
    dto: UpdateAvailabilityDto
  ): Promise<VendorAvailability> {
    await this.ensureExists(id);

    const availability = await this.prisma.vendorAvailability.update({
      where: { id },
      data: this.mapToUpdateData(dto)
    });

    await this.eventsPublisher.publishAvailabilityChanged({
      action: "updated",
      availability
    });

    return availability;
  }

  async remove(id: string): Promise<VendorAvailability> {
    const availability = await this.ensureExists(id);

    const deleted = await this.prisma.vendorAvailability.delete({
      where: { id }
    });

    await this.eventsPublisher.publishAvailabilityChanged({
      action: "deleted",
      availability
    });

    return deleted;
  }

  private async ensureExists(id: string): Promise<VendorAvailability> {
    const availability = await this.prisma.vendorAvailability.findUnique({
      where: { id }
    });

    if (!availability) {
      throw new NotFoundException(`Availability ${id} not found`);
    }

    return availability;
  }

  private mapToUpdateData(
    dto: UpdateAvailabilityDto
  ): Prisma.VendorAvailabilityUncheckedUpdateInput {
    const data: Prisma.VendorAvailabilityUncheckedUpdateInput = {};

    if (dto.vendorId !== undefined) {
      data.vendorId = dto.vendorId;
    }

    if (dto.eventDate !== undefined) {
      data.eventDate = dto.eventDate;
    }

    if (dto.isAvailable !== undefined) {
      data.isAvailable = dto.isAvailable;
    }

    if (dto.notes !== undefined) {
      data.notes = dto.notes ?? null;
    }

    return data;
  }
}
