import Link from "next/link";
import { notFound } from "next/navigation";
import { playfair } from "../../../lib/fonts";
import { getMessages } from "../../../lib/messages";
import { getSiteData } from "../../../lib/site-data";

type PageProps = {
  params: { slug: string };
};

export default async function CoupleWebsite({ params }: PageProps) {
  const site = await getSiteData(params.slug);

  if (!site) {
    notFound();
  }

  const messages = getMessages("ru");
  const eventDate = site.eventDate
    ? new Intl.DateTimeFormat("ru-RU", {
        day: "numeric",
        month: "long",
        year: "numeric",
        hour: "2-digit",
        minute: "2-digit"
      }).format(new Date(site.eventDate))
    : null;

  return (
    <main>
      <section className="hero">
        <h1 className={playfair.className}>{site.coupleNames}</h1>
        {eventDate && <p className="muted">{eventDate}</p>}
        {site.venue && (
          <p>
            {site.venue.name}
            <br />
            {site.venue.address}
          </p>
        )}
        <div className="actions">
          <Link
            className="button button-primary"
            href={`/w/${site.slug}/rsvp`}
          >
            {messages.actions.rsvp}
          </Link>
          <Link className="button button-outline" href={`/w/${site.slug}/info`}>
            {messages.actions.info}
          </Link>
        </div>
      </section>
      <section className="container">
        <div className="card">
          <h2>{messages.info.heading}</h2>
          <p className="muted">{site.story}</p>
        </div>
      </section>
    </main>
  );
}
