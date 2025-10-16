export type SiteData = {
  slug: string;
  coupleNames: string;
  eventDate?: string;
  venue?: {
    name: string;
    address: string;
    mapsUrl?: string;
  };
  schedule?: Array<{ time: string; title: string; description?: string }>;
  story?: string;
  accommodations?: string[];
  gifts?: string;
};

const demoSite: SiteData = {
  slug: "demo-couple",
  coupleNames: "Алишер & Захра",
  eventDate: "2025-10-12T15:00:00+05:00",
  venue: {
    name: "Тойхона «Navbahor»",
    address: "Ташкент, ул. Истиклол, 12",
    mapsUrl: "https://maps.google.com/?q=Navbahor+Tashkent"
  },
  schedule: [
    { time: "15:00", title: "Келин салом" },
    { time: "17:00", title: "Асосий маросим" },
    { time: "19:30", title: "Тантанали оқшом" }
  ],
  story:
    "Наши пути пересеклись на весеннем фестивале, а теперь мы празднуем новую главу вместе с вами.",
  accommodations: [
    "Hotel Tashkent Palace — блок комнат до 10.10",
    "Art Hostel — промокод WEDDINGTECH"
  ],
  gifts:
    "Ваше присутствие — лучший подарок. Если хотите поддержать начало семейной жизни, воспользуйтесь приглашением с QR-кодом."
};

export async function getSiteData(slug: string): Promise<SiteData | null> {
  if (slug === demoSite.slug) {
    return demoSite;
  }

  return null;
}
