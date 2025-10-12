export default function Home() {
  return (
    <main style={{ padding: 24, fontFamily: "system-ui, sans-serif" }}>
      <h1>WeddingTech — Frontend OK</h1>
      <ul>
        <li>
          <a href="/health">/health</a>
        </li>
        <li>
          <a href="/api/health">/api/health</a>
        </li>
        <li>
          <a href="/vendors/123">/vendors/[id] (пример)</a>
        </li>
      </ul>
    </main>
  );
}
