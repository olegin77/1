export default function Home({ params }: { params: { locale: string } }) {
  return (
    <main style={{ padding: 24 }}>
      <h1>Welcome — locale: {params.locale}</h1>
      <p>App Router i18n via middleware + [locale] segment.</p>
    </main>
  );
}
