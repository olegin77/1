import Link from "next/link";
import type { Metadata } from "next";
import { vendors } from "./data";

export const metadata: Metadata = {
  title: "Поставщики — WeddingTech",
  description: "Каталог проверенных поставщиков для свадьбы в Узбекистане."
};

export default async function VendorsPage() {
  return (
    <main className="vendors">
      <header className="vendors__header">
        <p className="vendors__eyebrow">Каталог</p>
        <h1>Поставщики</h1>
        <p className="vendors__subtitle">
          Подбор проверенных подрядчиков с живыми отзывами пар и актуальной
          доступностью по датам.
        </p>
      </header>
      <section className="vendors__grid">
        {vendors.map((vendor) => (
          <article key={vendor.id} className="vendor-card">
            <header className="vendor-card__header">
              <p className="vendor-card__category">{vendor.category}</p>
              <h2>{vendor.name}</h2>
              <p className="vendor-card__meta">
                {vendor.city} · {vendor.rating.toFixed(1)}★ · от{" "}
                {vendor.priceFrom.toLocaleString("ru-RU")} {vendor.currency}
              </p>
            </header>
            <ul className="vendor-card__highlights">
              {vendor.highlights.map((highlight) => (
                <li key={highlight}>{highlight}</li>
              ))}
            </ul>
            <footer className="vendor-card__footer">
              <span>
                Ответ в среднем: {vendor.responseTimeHours} ч
              </span>
              <Link href={`/vendors/${vendor.id}`} prefetch={false}>
                Смотреть профиль
              </Link>
            </footer>
          </article>
        ))}
      </section>
      <style jsx>{`
        .vendors {
          display: grid;
          gap: 32px;
          padding: 48px 32px;
        }

        .vendors__header {
          display: grid;
          gap: 12px;
          max-width: 640px;
        }

        .vendors__eyebrow {
          font-size: 0.85rem;
          letter-spacing: 0.08em;
          text-transform: uppercase;
          color: rgba(27, 31, 59, 0.6);
          margin: 0;
        }

        .vendors__header h1 {
          margin: 0;
          font-size: 2.5rem;
          letter-spacing: -0.02em;
        }

        .vendors__subtitle {
          margin: 0;
          font-size: 1.1rem;
          color: rgba(27, 31, 59, 0.72);
        }

        .vendors__grid {
          display: grid;
          gap: 24px;
          grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
        }

        .vendor-card {
          display: grid;
          gap: 16px;
          padding: 28px 24px;
          border-radius: 24px;
          background-color: #ffffff;
          box-shadow: 0 24px 48px rgba(13, 23, 67, 0.08);
        }

        .vendor-card__header h2 {
          margin: 6px 0 8px;
          font-size: 1.5rem;
          letter-spacing: -0.01em;
        }

        .vendor-card__category {
          margin: 0;
          font-size: 0.9rem;
          text-transform: uppercase;
          letter-spacing: 0.08em;
          color: rgba(27, 31, 59, 0.55);
        }

        .vendor-card__meta {
          margin: 0;
          color: rgba(27, 31, 59, 0.7);
          font-size: 0.95rem;
        }

        .vendor-card__highlights {
          margin: 0;
          padding-left: 20px;
          display: grid;
          gap: 8px;
          font-size: 0.95rem;
          color: rgba(27, 31, 59, 0.84);
        }

        .vendor-card__footer {
          display: flex;
          justify-content: space-between;
          align-items: center;
          font-size: 0.95rem;
          gap: 12px;
        }

        .vendor-card__footer a {
          padding: 10px 16px;
          border-radius: 999px;
          background: linear-gradient(135deg, #2d4bff, #9a66ff);
          color: #fff;
          font-weight: 600;
          letter-spacing: 0.02em;
        }

        @media (max-width: 640px) {
          .vendors {
            padding: 32px 16px;
          }

          .vendor-card__footer {
            flex-direction: column;
            align-items: flex-start;
          }
        }
      `}</style>
    </main>
  );
}
