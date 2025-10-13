import Link from "next/link";
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { findVendorById } from "../data";

type VendorPageProps = {
  params: {
    vendorId: string;
  };
};

export async function generateMetadata({
  params
}: VendorPageProps): Promise<Metadata> {
  const vendor = findVendorById(params.vendorId);

  if (!vendor) {
    return {
      title: "Поставщик не найден — WeddingTech"
    };
  }

  return {
    title: `${vendor.name} — ${vendor.category} · WeddingTech`,
    description: `Профиль поставщика ${vendor.name} (${vendor.city}). Рейтинг ${vendor.rating.toFixed(1)}. Стоимость от ${vendor.priceFrom.toLocaleString("ru-RU")} ${vendor.currency}. Средний ответ ${vendor.responseTimeHours} ч.`
  };
}

export default async function VendorDetailPage({
  params
}: VendorPageProps) {
  const vendor = findVendorById(params.vendorId) ?? notFound();

  return (
    <main className="vendor-detail">
      <nav className="vendor-detail__breadcrumbs" aria-label="Навигация">
        <Link href="/vendors" prefetch={false}>
          ← Назад к каталогу
        </Link>
      </nav>

      <header className="vendor-detail__header">
        <span className="vendor-detail__eyebrow">{vendor.category}</span>
        <h1>{vendor.name}</h1>
        <p className="vendor-detail__meta">
          {vendor.city} · рейтинг {vendor.rating.toFixed(1)}★ ·{" "}
          от {vendor.priceFrom.toLocaleString("ru-RU")} {vendor.currency} ·{" "}
          ответ {vendor.responseTimeHours} ч
        </p>
      </header>

      <section className="vendor-detail__section">
        <h2>Основные преимущества</h2>
        <ul>
          {vendor.highlights.map((highlight) => (
            <li key={highlight}>{highlight}</li>
          ))}
        </ul>
      </section>

      <section className="vendor-detail__cta">
        <Link href={`/planner?vendor=${vendor.id}`} prefetch={false}>
          Планировать с этим поставщиком
        </Link>
        <Link href="/vendors" prefetch={false}>
          Вернуться к каталогу
        </Link>
      </section>

      <section className="vendor-detail__note">
        <p>
          После согласования деталей переведите статус сделки в{" "}
          <strong>CONTRACT_SIGNED</strong>, чтобы включить ROI-триггеры и сбор
          отзывов пары.
        </p>
      </section>

      <style jsx>{`
        .vendor-detail {
          display: grid;
          gap: 32px;
          padding: 48px 32px;
          max-width: 960px;
          margin: 0 auto;
        }

        .vendor-detail__header {
          display: grid;
          gap: 12px;
          background-color: #ffffff;
          padding: 32px 28px;
          border-radius: 28px;
          box-shadow: 0 24px 48px rgba(13, 23, 67, 0.08);
        }

        .vendor-detail__breadcrumbs a {
          font-size: 0.9rem;
          color: rgba(27, 31, 59, 0.7);
        }

        .vendor-detail__eyebrow {
          font-size: 0.85rem;
          letter-spacing: 0.08em;
          text-transform: uppercase;
          color: rgba(27, 31, 59, 0.6);
        }

        .vendor-detail__header h1 {
          margin: 0;
          font-size: 2.75rem;
          letter-spacing: -0.02em;
        }

        .vendor-detail__meta {
          margin: 0;
          font-size: 1.05rem;
          color: rgba(27, 31, 59, 0.72);
        }

        .vendor-detail__section {
          background-color: #ffffff;
          padding: 28px 24px;
          border-radius: 24px;
          box-shadow: 0 24px 48px rgba(13, 23, 67, 0.08);
        }

        .vendor-detail__section h2 {
          margin-top: 0;
          margin-bottom: 16px;
        }

        .vendor-detail__section ul {
          margin: 0;
          padding-left: 20px;
          display: grid;
          gap: 12px;
          font-size: 1rem;
          color: rgba(27, 31, 59, 0.84);
        }

        .vendor-detail__cta {
          display: flex;
          flex-wrap: wrap;
          gap: 16px;
        }

        .vendor-detail__cta a:first-of-type {
          padding: 12px 22px;
          border-radius: 999px;
          background: linear-gradient(135deg, #2d4bff, #9a66ff);
          color: #ffffff;
          font-weight: 600;
        }

        .vendor-detail__cta a:last-of-type {
          padding: 12px 22px;
          border-radius: 999px;
          border: 1px solid rgba(27, 31, 59, 0.1);
          font-weight: 600;
        }

        .vendor-detail__note {
          background-color: #ffffff;
          padding: 24px 22px;
          border-radius: 20px;
          box-shadow: 0 16px 36px rgba(13, 23, 67, 0.08);
          font-size: 0.95rem;
          color: rgba(27, 31, 59, 0.75);
        }

        @media (max-width: 640px) {
          .vendor-detail {
            padding: 32px 16px;
          }

          .vendor-detail__header h1 {
            font-size: 2.1rem;
          }

          .vendor-detail__cta {
            flex-direction: column;
            align-items: stretch;
          }

          .vendor-detail__cta a {
            text-align: center;
          }
        }
      `}</style>
    </main>
  );
}
