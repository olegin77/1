import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException
} from "@nestjs/common";
import type { Enquiry, EnquiryStatus, Prisma } from "@prisma/client";
import { PrismaService } from "../prisma/prisma.service";
import { CreateEnquiryDto } from "./dto/create-enquiry.dto";
import { EnquiryQueryDto } from "./dto/enquiry-query.dto";
import { UpdateEnquiryDto } from "./dto/update-enquiry.dto";
import { UpdateEnquiryStatusDto } from "./dto/update-enquiry-status.dto";

type TransactionClient = Prisma.TransactionClient;

@Injectable()
export class EnquiriesService {
  private readonly logger = new Logger(EnquiriesService.name);

  private readonly transitions: Record<EnquiryStatus, EnquiryStatus[]> = {
    NEW: ["QUOTE_SENT"],
    QUOTE_SENT: ["MEETING_SCHEDULED"],
    MEETING_SCHEDULED: ["CONTRACT_SIGNED", "WON"],
    CONTRACT_SIGNED: ["WON"],
    WON: []
  };

  constructor(private readonly prisma: PrismaService) {}

  async create(dto: CreateEnquiryDto): Promise<Enquiry> {
    return this.prisma.enquiry.create({
      data: {
        vendorId: dto.vendorId,
        coupleName: dto.coupleName ?? null,
        contactEmail: dto.contactEmail ?? null,
        contactPhone: dto.contactPhone ?? null,
        budget: dto.budget ?? null,
        eventDate: dto.eventDate ?? null,
        source: dto.source ?? null,
        notes: dto.notes ?? null
      }
    });
  }

  async findAll(query: EnquiryQueryDto): Promise<Enquiry[]> {
    return this.prisma.enquiry.findMany({
      where: {
        vendorId: query.vendorId,
        status: query.status
      },
      orderBy: { createdAt: "desc" }
    });
  }

  async findOne(id: string): Promise<Enquiry> {
    const enquiry = await this.prisma.enquiry.findUnique({
      where: { id }
    });

    if (!enquiry) {
      throw new NotFoundException(`Enquiry ${id} not found`);
    }

    return enquiry;
  }

  async update(id: string, dto: UpdateEnquiryDto): Promise<Enquiry> {
    await this.ensureExists(id);

    return this.prisma.enquiry.update({
      where: { id },
      data: this.mapToUpdateData(dto)
    });
  }

  async updateStatus(
    id: string,
    dto: UpdateEnquiryStatusDto
  ): Promise<Enquiry> {
    return this.prisma.$transaction(async (tx) => {
      const enquiry = await tx.enquiry.findUnique({
        where: { id }
      });

      if (!enquiry) {
        throw new NotFoundException(`Enquiry ${id} not found`);
      }

      this.assertTransition(enquiry.status, dto.status);

      const canLeaveReview = this.shouldAllowReview(dto.status);

      const updated = await tx.enquiry.update({
        where: { id },
        data: {
          status: dto.status,
          canLeaveReview
        }
      });

      // После контрактов обновляем ROI-метрики в Postgres, чтобы фронт показывал актуальную конверсию.
      await this.refreshRoiMetrics(tx, updated.vendorId);

      if (canLeaveReview) {
        this.logger.log(
          `Enquiry ${updated.id} ready for couple review after status ${dto.status}`
        );
      }

      return updated;
    });
  }

  private async refreshRoiMetrics(
    tx: TransactionClient,
    vendorId: string
  ): Promise<void> {
    const signedCount = await tx.enquiry.count({
      where: {
        vendorId,
        status: { in: ["CONTRACT_SIGNED", "WON"] }
      }
    });

    const wonCount = await tx.enquiry.count({
      where: {
        vendorId,
        status: "WON"
      }
    });

    await tx.roiMetric.upsert({
      where: { vendorId },
      update: {
        signedCount,
        wonCount
      },
      create: {
        vendorId,
        signedCount,
        wonCount
      }
    });
  }

  private mapToUpdateData(
    dto: UpdateEnquiryDto
  ): Prisma.EnquiryUncheckedUpdateInput {
    const data: Prisma.EnquiryUncheckedUpdateInput = {};

    if (dto.vendorId !== undefined) {
      data.vendorId = dto.vendorId;
    }

    if (dto.coupleName !== undefined) {
      data.coupleName = dto.coupleName ?? null;
    }

    if (dto.contactEmail !== undefined) {
      data.contactEmail = dto.contactEmail ?? null;
    }

    if (dto.contactPhone !== undefined) {
      data.contactPhone = dto.contactPhone ?? null;
    }

    if (dto.budget !== undefined) {
      data.budget = dto.budget ?? null;
    }

    if (dto.eventDate !== undefined) {
      data.eventDate = dto.eventDate ?? null;
    }

    if (dto.source !== undefined) {
      data.source = dto.source ?? null;
    }

    if (dto.notes !== undefined) {
      data.notes = dto.notes ?? null;
    }

    return data;
  }

  private assertTransition(current: EnquiryStatus, next: EnquiryStatus) {
    const allowed = this.transitions[current] ?? [];
    if (!allowed.includes(next)) {
      throw new BadRequestException(
        `Cannot transition enquiry from ${current} to ${next}`
      );
    }
  }

  private shouldAllowReview(status: EnquiryStatus): boolean {
    return status === "CONTRACT_SIGNED" || status === "WON";
  }

  private async ensureExists(id: string): Promise<void> {
    const exists = await this.prisma.enquiry.findUnique({
      where: { id },
      select: { id: true }
    });

    if (!exists) {
      throw new NotFoundException(`Enquiry ${id} not found`);
    }
  }
}
