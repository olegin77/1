import { notFound } from "next/navigation";
import { RsvpForm } from "../../../../components/RsvpForm";
import { getSiteData } from "../../../../lib/site-data";

type PageProps = {
  params: { slug: string };
};

export default async function RsvpPage({ params }: PageProps) {
  const site = await getSiteData(params.slug);

  if (!site) {
    notFound();
  }

  return (
    <main className="container">
      <div className="card">
        <RsvpForm slug={site.slug} />
      </div>
    </main>
  );
}
