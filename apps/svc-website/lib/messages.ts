const translations = {
  ru: {
    hero: {
      headline: "Свадебный сайт для пары",
      tagline:
        "Поделитесь историей, таймингом торжества и собирайте RSVP в одном месте."
    },
    actions: {
      rsvp: "Ответить на приглашение",
      info: "Посмотреть подробности"
    },
    rsvp: {
      heading: "Подтвердите участие",
      description:
        "Расскажите, придёте ли на праздник, и поделитесь пожеланиями для пары.",
      name: "Ваше имя",
      email: "Email",
      phone: "Телефон",
      message: "Сообщение",
      attending: "Приду на свадьбу",
      submit: "Отправить ответ",
      success: "Спасибо! Мы записали ваш ответ."
    },
    info: {
      heading: "Информация о торжестве",
      schedule: "Расписание",
      location: "Локация",
      accommodations: "Проживание",
      gifts: "Подарки и пожелания"
    }
  },
  uz: {
    hero: {
      headline: "To‘y sayti",
      tagline:
        "Sevimli juftlik tarixi, marosim jadvali va RSVP javoblari bir joyda."
    },
    actions: {
      rsvp: "Taklifga javob berish",
      info: "Batafsil ma’lumot"
    },
    rsvp: {
      heading: "Ishtirokingizni tasdiqlang",
      description:
        "To‘yga kelishingizni bildiring va juftlikka tilaklaringizni yozing.",
      name: "Ismingiz",
      email: "Email",
      phone: "Telefon",
      message: "Xabar",
      attending: "Men to‘yga kelaman",
      submit: "Javobni yuborish",
      success: "Rahmat! Javobingiz qabul qilindi."
    },
    info: {
      heading: "Marosim tafsilotlari",
      schedule: "Dastur",
      location: "Manzil",
      accommodations: "Joylashish",
      gifts: "Sovg‘alar va tilaklar"
    }
  }
} as const;

export type SupportedLocale = keyof typeof translations;

export function getMessages(locale: string) {
  if (locale in translations) {
    return translations[locale as SupportedLocale];
  }

  return translations.ru;
}
