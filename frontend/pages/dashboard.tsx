import type { NextPage } from "next";

const leads = [
  {
    id: "LEAD-2301",
    name: "Саида Ергашева",
    priority: "Высокий",
    status: "NEW",
    phone: "+998 90 123 45 67",
    email: "saida@example.uz",
    nextStep: "Позвонить до 16:00"
  },
  {
    id: "LEAD-2298",
    name: "Aziz & Madina",
    priority: "Средний",
    status: "QUOTE_SENT",
    phone: "+998 93 555 44 33",
    email: "aziz.madina@example.com",
    nextStep: "Ожидаем ответ по коммерческому"
  }
];

const metrics = [
  { label: "Активные заявки", value: 42 },
  { label: "ROI (30 дней)", value: "162%" },
  { label: "Новых за неделю", value: 18 },
  { label: "Контрактов на подписи", value: 5 }
];

const pipeline = [
  { stage: "NEW", count: 18 },
  { stage: "QUOTE_SENT", count: 12 },
  { stage: "MEETING_SCHEDULED", count: 6 },
  { stage: "CONTRACT_SIGNED", count: 4 },
  { stage: "WON", count: 2 }
];

const DashboardPage: NextPage = () => {
  return (
    <main className="dashboard">
      <section className="panel quick-analytics">
        <header>
          <h1>Быстрая аналитика</h1>
        </header>
        <div className="metrics">
          {metrics.map((item) => (
            <article key={item.label} className="metric-card">
              <span className="metric-label">{item.label}</span>
              <span className="metric-value">{item.value}</span>
            </article>
          ))}
        </div>
      </section>

      <section className="panel follow-up">
        <header>
          <h2>Контроль follow-up</h2>
          <p>Фокус на задачах, которые требуют ответа сегодня.</p>
        </header>
        <ul className="lead-list">
          {leads.map((lead) => (
            <li key={lead.id}>
              <article className="lead-card" aria-label={`Лид ${lead.name}`}>
                <div data-field="name">
                  <span data-field-label="label">Имя</span>
                  <strong>{lead.name}</strong>
                </div>
                <div data-field="priority">
                  <span data-field-label="label">Приоритет</span>
                  <span>{lead.priority}</span>
                </div>
                <div data-field="status">
                  <span data-field-label="label">Статус</span>
                  <span>{lead.status}</span>
                </div>
                <div data-field="phone">
                  <span data-field-label="label">Телефон</span>
                  <a href={`tel:${lead.phone}`}>{lead.phone}</a>
                </div>
                <div data-field="email">
                  <span data-field-label="label">Email</span>
                  <a href={`mailto:${lead.email}`}>{lead.email}</a>
                </div>
                <div data-field="next-step">
                  <span data-field-label="label">Следующий шаг</span>
                  <span>{lead.nextStep}</span>
                </div>
              </article>
            </li>
          ))}
        </ul>
      </section>

      <section className="panel pipeline">
        <header>
          <h2>Воронка</h2>
        </header>
        <table className="responsive-table" aria-label="Воронка продаж">
          <thead>
            <tr>
              <th>Стадия</th>
              <th>Кол-во лидов</th>
            </tr>
          </thead>
          <tbody>
            {pipeline.map((row) => (
              <tr key={row.stage}>
                <td data-header="Стадия">{row.stage}</td>
                <td data-header="Кол-во лидов">{row.count}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      <section className="panel notes">
        <header>
          <h2>Заметки</h2>
        </header>
        <p>
          Сегментируйте follow-up по приоритету и статусу. Важные пары (PRIO
          High) переключайте в режим ручного сопровождения.
        </p>
      </section>

      <style jsx>{`
        .dashboard {
          display: grid;
          gap: 24px;
          padding: 32px;
          grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
        }

        .panel {
          background-color: #ffffff;
          border-radius: 24px;
          padding: 24px;
          box-shadow: 0 24px 48px rgba(13, 23, 67, 0.08);
        }

        .panel header > h1,
        .panel header > h2 {
          margin: 0 0 12px;
          font-weight: 600;
          letter-spacing: -0.01em;
        }

        .metrics {
          display: grid;
          gap: 16px;
          grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
        }

        .metric-card {
          display: grid;
          gap: 4px;
          padding: 18px;
          border-radius: 18px;
          background: linear-gradient(135deg, #2d4bff, #9a66ff);
          color: #ffffff;
        }

        .metric-label {
          font-size: 0.85rem;
          text-transform: uppercase;
          opacity: 0.8;
          letter-spacing: 0.08em;
        }

        .metric-value {
          font-size: 1.65rem;
          font-weight: 700;
        }

        .lead-list {
          list-style: none;
          margin: 0;
          padding: 0;
          display: grid;
          gap: 16px;
        }

        .pipeline {
          align-self: start;
        }

        @media (min-width: 1024px) {
          .dashboard {
            grid-template-columns: 2fr 1fr;
            grid-auto-rows: minmax(0, max-content);
          }

          .quick-analytics {
            grid-column: 1 / span 1;
          }

          .follow-up {
            grid-column: 1 / span 1;
          }

          .pipeline {
            grid-column: 2 / span 1;
          }

          .notes {
            grid-column: 2 / span 1;
          }
        }

        @media (max-width: 640px) {
          .dashboard {
            padding: 24px 16px;
          }

          .quick-analytics {
            order: 1;
          }

          .follow-up {
            order: 2;
          }

          .pipeline {
            order: 3;
          }

          .notes {
            order: 4;
          }
        }
      `}</style>
    </main>
  );
};

export default DashboardPage;
