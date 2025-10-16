type RsvpPayload = {
  name: string;
  email: string;
  phone: string;
  message: string;
  attending: boolean;
};

export async function postRsvp(slug: string, data: RsvpPayload) {
  const response = await fetch("/api/rsvp", {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      slug,
      ...data
    })
  });

  if (!response.ok) {
    throw new Error("Не удалось отправить ответ. Попробуйте ещё раз позже.");
  }

  return response.json();
}
