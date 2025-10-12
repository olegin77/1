import Link from "next/link";
import { notFound } from "next/navigation";
import type { Metadata } from "next";
import { findVendorById } from "../data";

type PageProps = {
  params: {
    vendorId: string;
  };
};

export async function generateMetadata({
  params
}: PageProps): Promise<Metadata> {
  const vendor = findVendorById(params.vendorId);
  if (!vendor) {
    return {
      title: "Поставщик не найден — WeddingTech"
    };
  }

  return {
    title: `${vendor.name} — WeddingTech`,
    description: `${vendor.category} в ${vendor.city}. Средний ответ ${vendor.responseTimeHours} ч.`
  };
}

export default async function VendorProfile({ params }: PageProps) {
  const vendor = findVendorById(params.vendorId);
  if (!vendor) {
    notFound();
  }

  return (
    <main className="vendor-profile">
      <nav className="vendor-profile__breadcrumbs" aria-label="Навигация">
        <Link href="/vendors" prefetch={false}>
          ← Назад к каталогу
        </Link>
      </nav>

      <header className="vendor-profile__header">
        <p className="vendor-profile__tag">{vendor.category}</p>
        <h1>{vendor.name}</h1>
        <p className="vendor-profile__meta">
          {vendor.city} · {vendor.rating.toFixed(1)}★ · от{" "}
          {vendor.priceFrom.toLocaleString("ru-RU")} {vendor.currency}
        </p>
      </header>

      <section className="vendor-profile__section">
        <h2>Что входит</h2>
        <ul>
          {vendor.highlights.map((item) => (
            <li key={item}>{item}</li>
          ))}
        </ul>
      </section>

      <section className="vendor-profile__section vendor-profile__cta">
        <div>
          <h2>Проверить дату</h2>
          <p>
            Мы запросим подтверждение и отправим вам ответ в течение{" "}
            {vendor.responseTimeHours} часов.
          </p>
        </div>
        <Link href={`/planner?vendor=${vendor.id}`} prefetch={false}>
          Добавить в план
        </Link>
      </section>

      <style jsx>{`
        .vendor-profile {
          display: grid;
          gap: 32px;
          padding: 48px 32px;
        }

        .vendor-profile__breadcrumbs a {
          font-size: 0.9rem;
          color: rgba(27, 31, 59, 0.7);
        }

        .vendor-profile__tag {
          font-size: 0.85rem;
          letter-spacing: 0.08em;
          text-transform: uppercase;
          color: rgba(27, 31, 59, 0.6);
          margin: 0 0 12px;
        }

        .vendor-profile__header h1 {
          margin: 0;
          font-size: 2.5rem;
          letter-spacing: -0.02em;
        }

        .vendor-profile__meta {
          margin: 12px 0 0;
          font-size: 1.05rem;
          color: rgba(27, 31, 59, 0.72);
        }

        .vendor-profile__section {
          background-color: #ffffff;
          padding: 28px 24px;
          border-radius: 24px;
          box-shadow: 0 24px 48px rgba(13, 23, 67, 0.08);
        }

        .vendor-profile__section h2 {
          margin-top: 0;
          font-size: 1.5rem;
        }

        .vendor-profile__section ul {
          margin: 16px 0 0;
          padding-left: 20px;
          display: grid;
          gap: 12px;
        }

        .vendor-profile__cta {
          display: flex;
          justify-content: space-between;
          align-items: center;
          gap: 16px;
        }

        .vendor-profile__cta a {
          padding: 12px 24px;
          border-radius: 999px;
          background: linear-gradient(135deg, #2d4bff, #9a66ff);
          color: #ffffff;
          font-weight: 600;
          letter-spacing: 0.02em;
        }

        @media (max-width: 640px) {
          .vendor-profile {
            padding: 32px 16px;
          }

          .vendor-profile__cta {
            flex-direction: column;
            align-items: flex-start;
          }
        }
      `}</style>
    </main>
  );
}
