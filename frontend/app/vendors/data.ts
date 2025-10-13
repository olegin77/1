export type Vendor = {
  id: string;
  name: string;
  category: string;
  city: string;
  rating: number;
  priceFrom: number;
  currency: "UZS";
  responseTimeHours: number;
  highlights: string[];
};

export const vendors: Vendor[] = [
  {
    id: "floristico",
    name: "Floristico Boutique",
    category: "Флористика и декор",
    city: "Ташкент",
    rating: 4.9,
    priceFrom: 4500000,
    currency: "UZS",
    responseTimeHours: 2,
    highlights: [
      "Авторские композиции для девушек-невест",
      "Полная стилизация площадки",
      "Координация поставщиков"
    ]
  },
  {
    id: "samarqand-hall",
    name: "Samarqand Hall",
    category: "Площадка",
    city: "Самарканд",
    rating: 4.7,
    priceFrom: 18000000,
    currency: "UZS",
    responseTimeHours: 6,
    highlights: [
      "Световые инсталляции в восточном стиле",
      "Зал на 350 гостей + веранда",
      "Техническая команда 24/7"
    ]
  },
  {
    id: "luxe-photo",
    name: "Luxe Photo Studio",
    category: "Фото и видео",
    city: "Бухара",
    rating: 4.8,
    priceFrom: 6000000,
    currency: "UZS",
    responseTimeHours: 4,
    highlights: [
      "Съёмка love-story и дня торжества",
      "Пакеты с дроном и второй камерой",
      "Готовые альбомы за 10 дней"
    ]
  }
];

export function findVendorById(id: string) {
  return vendors.find((vendor) => vendor.id === id);
}
