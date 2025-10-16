"use client";

import { useTranslations } from "next-intl";
import { useState } from "react";
import { postRsvp } from "../lib/rsvp";

type Props = {
  slug: string;
};

export function RsvpForm({ slug }: Props) {
  const [formState, setFormState] = useState({
    name: "",
    email: "",
    phone: "",
    message: "",
    attending: true
  });
  const [status, setStatus] = useState<"idle" | "loading" | "success" | "error">("idle");
  const [error, setError] = useState<string | null>(null);

  const t = useTranslations("rsvp");

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatus("loading");
    setError(null);

    try {
      await postRsvp(slug, formState);
      setStatus("success");
    } catch (err) {
      setStatus("error");
      setError(err instanceof Error ? err.message : "Failed to submit RSVP.");
    }
  }

  return (
    <form onSubmit={handleSubmit}>
      <h2>{t("heading")}</h2>
      <p className="muted">{t("description")}</p>

      <label>
        {t("name")}
        <input
          type="text"
          required
          autoComplete="name"
          value={formState.name}
          onChange={(event) =>
            setFormState({ ...formState, name: event.target.value })
          }
        />
      </label>
      <label>
        {t("email")}
        <input
          type="email"
          autoComplete="email"
          value={formState.email}
          onChange={(event) =>
            setFormState({ ...formState, email: event.target.value })
          }
        />
      </label>
      <label>
        {t("phone")}
        <input
          type="tel"
          autoComplete="tel"
          value={formState.phone}
          onChange={(event) =>
            setFormState({ ...formState, phone: event.target.value })
          }
        />
      </label>
      <label>
        {t("message")}
        <textarea
          rows={4}
          value={formState.message}
          onChange={(event) =>
            setFormState({ ...formState, message: event.target.value })
          }
        />
      </label>
      <label
        style={{
          display: "flex",
          alignItems: "center",
          gap: "0.75rem",
          fontWeight: 500
        }}
      >
        <input
          type="checkbox"
          checked={formState.attending}
          onChange={(event) =>
            setFormState({ ...formState, attending: event.target.checked })
          }
        />
        {t("attending")}
      </label>

      <button
        className="button button-primary"
        type="submit"
        disabled={status === "loading"}
      >
        {status === "loading" ? "Отправка..." : t("submit")}
      </button>

      {status === "success" && <p className="muted">{t("success")}</p>}
      {status === "error" && error && <p className="muted">{error}</p>}
    </form>
  );
}
