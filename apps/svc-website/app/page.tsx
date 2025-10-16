import Link from "next/link";
import { getMessages } from "../lib/messages";

export default function Home() {
  const messages = getMessages("ru");

  return (
    <main>
      <section className="hero">
        <h1>{messages.hero.headline}</h1>
        <p className="muted">
          {messages.hero.tagline} Чтобы посмотреть конкретный свадебный сайт,
          откройте ссылку вида <strong>/w/alisher-zahra</strong>.
        </p>
        <div className="actions">
          <Link className="button button-primary" href="/w/demo-couple/rsvp">
            {messages.actions.rsvp}
          </Link>
          <Link className="button button-outline" href="/w/demo-couple/info">
            {messages.actions.info}
          </Link>
        </div>
      </section>
    </main>
  );
}
