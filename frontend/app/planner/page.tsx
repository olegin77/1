import Link from "next/link";
import type { Metadata } from "next";
import { vendors } from "../vendors/data";

type PageProps = {
  searchParams: {
    vendor?: string;
  };
};

export const metadata: Metadata = {
  title: "Планировщик — WeddingTech",
  description:
    "Управляйте брифом, задачами и бюджетом по свадьбе в единой панели."
};

const checklist = [
  { id: "timeline", label: "Уточнить тайминг дня торжества", due: "Сегодня" },
  { id: "venue", label: "Подтвердить площадку и согласовать макет", due: "3 дня" },
  {
    id: "payments",
    label: "Разнести оплату по поставщикам (UZS)",
    due: "7 дней"
  }
];

const budget = [
  { id: "decor", label: "Декор и флористика", amount: 125000000 },
  { id: "photo", label: "Фото и видео", amount: 48000000 },
  { id: "venue", label: "Аренда площадки", amount: 210000000 }
];

export default async function PlannerPage({ searchParams }: PageProps) {
  const selectedVendor = searchParams.vendor
    ? vendors.find((vendor) => vendor.id === searchParams.vendor)
    : undefined;

  return (
    <main className="planner">
      <header className="planner__header">
        <h1>Планировщик</h1>
        <p>
          Управление задачами и бюджетом пары. Все статусы синхронизированы с
          командами поставщиков.
        </p>
      </header>

      {selectedVendor ? (
        <section className="planner__section planner__selection">
          <h2>Вы выбрали: {selectedVendor.name}</h2>
          <p>
            Категория: {selectedVendor.category} · {selectedVendor.city} ·{" "}
            {selectedVendor.rating.toFixed(1)}★
          </p>
          <Link href={`/vendors/${selectedVendor.id}`} prefetch={false}>
            Посмотреть профиль поставщика
          </Link>
        </section>
      ) : null}

      <section className="planner__section planner__tasks">
        <header>
          <h2>Задачи</h2>
          <p>Отслеживайте обязательные шаги, чтобы закрыть сделку.</p>
        </header>
        <ul>
          {checklist.map((task) => (
            <li key={task.id}>
              <article>
                <strong>{task.label}</strong>
                <span className="planner__tasks-due">Дедлайн: {task.due}</span>
              </article>
            </li>
          ))}
        </ul>
      </section>

      <section className="planner__section planner__budget">
        <header>
          <h2>Бюджет</h2>
          <p>Соберите все платежи в UZS и контролируйте остаток.</p>
        </header>
        <table className="responsive-table" aria-label="Бюджет">
          <thead>
            <tr>
              <th>Статья</th>
              <th>Сумма, UZS</th>
            </tr>
          </thead>
          <tbody>
            {budget.map((item) => (
              <tr key={item.id}>
                <td data-header="Статья">{item.label}</td>
                <td data-header="Сумма, UZS">
                  {item.amount.toLocaleString("ru-RU")}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      <section className="planner__section planner__notes">
        <header>
          <h2>Рабочие заметки</h2>
        </header>
        <p>
          Когда контракт подписан, обновите статус лота смежных поставщиков,
          чтобы система рассчитала ROI и открыла пару для сбора отзывов.
        </p>
      </section>

      <style jsx>{`
        .planner {
          display: grid;
          gap: 32px;
          padding: 48px 32px;
        }

        .planner__header h1 {
          margin: 0 0 12px;
          font-size: 2.5rem;
          letter-spacing: -0.02em;
        }

        .planner__header p {
          margin: 0;
          font-size: 1.1rem;
          color: rgba(27, 31, 59, 0.72);
        }

        .planner__section {
          background-color: #ffffff;
          padding: 28px 24px;
          border-radius: 24px;
          box-shadow: 0 24px 48px rgba(13, 23, 67, 0.08);
          display: grid;
          gap: 16px;
        }

        .planner__tasks ul {
          margin: 0;
          padding: 0;
          list-style: none;
          display: grid;
          gap: 12px;
        }

        .planner__tasks article {
          display: flex;
          justify-content: space-between;
          align-items: center;
          gap: 12px;
        }

        .planner__tasks-due {
          font-size: 0.85rem;
          color: rgba(27, 31, 59, 0.65);
        }

        .planner__budget table {
          margin-top: 8px;
        }

        .planner__selection a {
          justify-self: flex-start;
          padding: 10px 18px;
          border-radius: 999px;
          background: linear-gradient(135deg, #2d4bff, #9a66ff);
          color: #ffffff;
          font-weight: 600;
        }

        @media (max-width: 640px) {
          .planner {
            padding: 32px 16px;
          }
        }
      `}</style>
    </main>
  );
}
