import { notFound } from "next/navigation";
import { getMessages } from "../../../../lib/messages";
import { getSiteData } from "../../../../lib/site-data";

type PageProps = {
  params: { slug: string };
};

export default async function InfoPage({ params }: PageProps) {
  const site = await getSiteData(params.slug);

  if (!site) {
    notFound();
  }

  const messages = getMessages("ru");

  return (
    <main className="container">
      <div className="grid-two">
        <article className="card">
          <h2>{messages.info.schedule}</h2>
          <div>
            {site.schedule?.map((item) => (
              <p key={item.time}>
                <strong>{item.time}</strong> — {item.title}
                {item.description ? ` · ${item.description}` : ""}
              </p>
            )) ?? <p className="muted">Расписание появится позже.</p>}
          </div>
        </article>
        <article className="card">
          <h2>{messages.info.location}</h2>
          <p>
            {site.venue?.name}
            <br />
            {site.venue?.address}
          </p>
          {site.venue?.mapsUrl && (
            <p>
              <a
                className="button button-outline"
                href={site.venue.mapsUrl}
                target="_blank"
                rel="noreferrer"
              >
                Открыть в картах
              </a>
            </p>
          )}
        </article>
      </div>
      <div className="grid-two" style={{ marginTop: "2rem" }}>
        <article className="card">
          <h2>{messages.info.accommodations}</h2>
          <ul>
            {site.accommodations?.map((item) => (
              <li key={item}>{item}</li>
            )) ?? <li className="muted">Рекомендации появятся позже.</li>}
          </ul>
        </article>
        <article className="card">
          <h2>{messages.info.gifts}</h2>
          <p>{site.gifts ?? "Пара пока не поделилась пожеланиями."}</p>
        </article>
      </div>
    </main>
  );
}
