import Link from "next/link";

export default function NotFound() {
  return (
    <main className="container">
      <div className="card" style={{ textAlign: "center" }}>
        <h1>Сайт не найден</h1>
        <p className="muted">
          Возможно, пара ещё не опубликовала свой сайт или ссылка неактивна.
        </p>
        <p>
          <Link className="button button-outline" href="/">
            Вернуться на главную
          </Link>
        </p>
      </div>
    </main>
  );
}
