export default function Home() {
  return (
    <main style={{ padding: 24, fontFamily: "system-ui, sans-serif" }}>
      <h1>WeddingTech — Frontend OK</h1>
      <ul>
        <li>
          <a href="/health">/health</a>
        </li>
        <li>
          <a href="/dashboard">/dashboard</a>
        </li>
        <li>
          <a href="/vendors/123">/vendors/[id] (пример)</a>
        </li>
        <li>
          <a href="/vendors">/vendors</a>
        </li>
        <li>
          <a href="/planner">/planner</a>
        </li>
        <li>
          <a href="/api/health">/api/health</a>
        </li>
      </ul>
    </main>
  );
}
