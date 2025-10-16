import { NextResponse } from "next/server";

type RsvpBody = {
  slug?: string;
  name?: string;
  email?: string;
  phone?: string;
  message?: string;
  attending?: boolean;
};

export async function POST(request: Request) {
  const body = (await request.json()) as RsvpBody;

  if (!body.slug || !body.name) {
    return NextResponse.json(
      { error: "Slug and name are required." },
      { status: 400 }
    );
  }

  // TODO: integrate with svc-guests API once available.
  console.info("RSVP received", {
    slug: body.slug,
    name: body.name,
    email: body.email,
    attending: body.attending ?? false
  });

  return NextResponse.json({ status: "ok" }, { status: 201 });
}
